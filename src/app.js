const express = require('express');
const mongoose = require('mongoose');
const redis = require('redis');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const morgan = require('morgan');

const app = express();
const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet());
app.use(cors());
app.use(compression());
app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

let redisClient;

// MongoDB connection
const connectMongoDB = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/products');
    console.log('✅ Connected to MongoDB');
  } catch (error) {
    console.error('❌ MongoDB connection error:', error);
    process.exit(1);
  }
};

// Redis connection with proper error handling and authentication
const connectRedis = async () => {
  try {
    const client = redis.createClient({
      url: process.env.REDIS_URL || 'redis://localhost:6379',
      password: process.env.REDIS_PASSWORD,
      // Add these connection options for better stability
      socket: {
        reconnectStrategy: (retries) => Math.min(retries * 50, 1000),
        connectTimeout: 60000,
        lazyConnect: true
      },
      // Retry configuration
      retry_unfulfilled_commands: true,
      enable_offline_queue: false
    });
    
    // Enhanced error handling
    client.on('error', (err) => {
      console.error('❌ Redis Client Error:', err.message);
      if (err.message.includes('NOAUTH')) {
        console.error('💡 Hint: Check your REDIS_PASSWORD environment variable');
      }
    });
    
    client.on('connect', () => {
      console.log('🔄 Redis client connected');
    });
    
    client.on('ready', () => {
      console.log('✅ Redis client ready');
    });
    
    client.on('end', () => {
      console.log('🔚 Redis client disconnected');
    });
    
    client.on('reconnecting', () => {
      console.log('🔄 Redis client reconnecting...');
    });
    
    await client.connect();
    console.log('✅ Connected to Redis');
    redisClient = client;
    return client;
  } catch (error) {
    console.error('❌ Redis connection error:', error.message);
    // Don't exit the process, continue without Redis
    console.log('⚠️ Continuing without Redis cache...');
    redisClient = null;
    return null;
  }
};

// Define Product Schema and Model
const productSchema = new mongoose.Schema({
  name: String,
  price: Number,
  description: String,
});

const Product = mongoose.model('Product', productSchema);

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development'
  });
});

// Updated API route with Redis fallback handling
app.get('/api/products', async (req, res) => {
  try {
    const cacheKey = 'products';
    let cachedProducts = null;

    console.log('Getting products!')
    console.log(process.env.REDIS_PASSWORD)

    // Only try Redis if client is available and connected
    if (redisClient && redisClient.isReady) {
      try {
        cachedProducts = await redisClient.get(cacheKey);
      } catch (redisError) {
        console.error('❌ Redis get error:', redisError.message);
        // Continue without cache
      }
    }

    if (cachedProducts) {
      console.log('Cache Hit');
      return res.json({
        success: true,
        data: JSON.parse(cachedProducts),
        message: 'Products retrieved from cache'
      });
    } else {
      console.log('Cache Miss or Redis unavailable');
      // Fetch from MongoDB
      const products = await Product.find({});

      // Try to cache if Redis is available
      if (redisClient && redisClient.isReady && products.length > 0) {
        try {
          await redisClient.set(cacheKey, JSON.stringify(products), { EX: 3600 });
          console.log('✅ Products cached in Redis');
        } catch (redisError) {
          console.error('❌ Redis set error:', redisError.message);
          // Continue without caching
        }
      }

      res.json({
        success: true,
        data: products,
        message: 'Products retrieved successfully'
      });
    }
  } catch (error) {
    console.error('❌ Error fetching products:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    success: false,
    error: 'Something went wrong!'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    error: 'Route not found'
  });
});

// Start server
const startServer = async () => {
  await connectMongoDB();
  await connectRedis();
  
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);
  });
};

startServer().catch(console.error);
