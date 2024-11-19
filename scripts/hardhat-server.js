const express = require("express");
const { exec } = require("child_process");
const { promisify } = require("util");
const cors = require("cors");

const execAsync = promisify(exec);
const app = express();

app.use(cors());
app.use(express.json());

async function executeHardhatTask(taskName, params) {
  let command = `npx hardhat ${taskName}`;

  if (params) {
    Object.entries(params).forEach(([key, value]) => {
      command += ` --${key} "${value}"`;
    });
  }

  console.log(`Executing command: ${command}`);

  try {
    const { stdout, stderr } = await execAsync(command);
    if (stderr) {
      console.error("Stderr:", stderr);
    }
    return stdout;
  } catch (error) {
    console.error("Error executing Hardhat task:", error);
    throw error;
  }
}

app.post("/execute-task", async (req, res) => {
  try {
    const { task, params } = req.body;

    // Special handling for ping task
    if (task === "ping") {
      console.log("Ping received, frontend is connected");
      return res.sendStatus(200);
    }

    const result = await executeHardhatTask(task, params);
    res.json({ success: true, data: result });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message || "Failed to execute Hardhat task"
    });
  }
});

const PORT = 3002;
app.listen(PORT, () => {
  console.log(`Task server running on port ${PORT}`);
});
