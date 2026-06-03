const mongoose = require('mongoose');

const connectDB = async () => {
  try {
    // FIX: Removed deprecated useNewUrlParser and useUnifiedTopology options
    // (Mongoose 8.x no longer accepts them and they cause warnings)
    const conn = await mongoose.connect(process.env.MONGODB_URI);
    console.log(`✅ MongoDB Connected: ${conn.connection.host}`);
  } catch (error) {
    console.error('❌ MongoDB connection error:', error.message);
    console.error('👉 Check your MONGODB_URI in .env — it must be your Atlas connection string,');
    console.error('   not mongodb://localhost:27017. Get it from: Atlas → Connect → Drivers → Node.js');
    process.exit(1);
  }
};

module.exports = connectDB;
