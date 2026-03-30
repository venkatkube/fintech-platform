const express = require("express");
const amqp = require("amqplib");
const mongoose = require("mongoose");

const app = express();
app.use(express.json());

let channel;
let mongoReady = false;
let rabbitReady = false;

/* ------------------ Mongo Connection with Retry ------------------ */
async function connectMongo(retries = 5) {
  try {
    await mongoose.connect("mongodb://mongodb:27017/txn");
    mongoReady = true;
    console.log("MongoDB connected");
  } catch (err) {
    console.error("MongoDB connection failed, retrying...", err.message);
    if (retries > 0) {
      setTimeout(() => connectMongo(retries - 1), 5000);
    }
  }
}

/* ------------------ RabbitMQ Connection with Retry ------------------ */
async function connectRabbit(retries = 5) {
  try {
    const conn = await amqp.connect("amqp://rabbitmq");
    channel = await conn.createChannel();

    await channel.assertQueue("txn.created", { durable: true });
    await channel.assertQueue("txn.dlq", { durable: true });

    rabbitReady = true;
    console.log("RabbitMQ connected");
  } catch (err) {
    console.error("RabbitMQ connection failed, retrying...", err.message);
    if (retries > 0) {
      setTimeout(() => connectRabbit(retries - 1), 5000);
    }
  }
}

/* ------------------ Health Endpoints ------------------ */
app.get("/health", (req, res) => {
  if (mongoReady && rabbitReady) {
    return res.status(200).send("OK");
  }
  return res.status(500).send("NOT_READY");
});

/* ------------------ Transaction API ------------------ */
app.post("/transaction", async (req, res) => {
  if (!mongoReady || !rabbitReady) {
    return res.status(503).send({ error: "Service not ready" });
  }

  try {
    const txn = req.body;

    if (!txn || !txn.amount) {
      return res.status(400).send({ error: "Invalid payload" });
    }

    await mongoose.connection.collection("transactions").insertOne({
      ...txn,
      createdAt: new Date()
    });

    channel.sendToQueue(
      "txn.created",
      Buffer.from(JSON.stringify(txn)),
      { persistent: true }
    );

    console.log("Transaction processed:", txn);

    res.send({ status: "ok" });
  } catch (err) {
    console.error("Transaction failed:", err.message);

    if (channel) {
      channel.sendToQueue(
        "txn.dlq",
        Buffer.from(JSON.stringify(req.body)),
        { persistent: true }
      );
    }

    res.status(500).send({ error: "failed" });
  }
});

/* ------------------ Graceful Shutdown ------------------ */
process.on("SIGTERM", async () => {
  console.log("Shutting down...");
  await mongoose.disconnect();
  process.exit(0);
});

/* ------------------ Start Server ------------------ */
app.listen(3000, async () => {
  console.log("Starting service...");

  await connectMongo();
  await connectRabbit();

  console.log("Service running on port 3000");
});