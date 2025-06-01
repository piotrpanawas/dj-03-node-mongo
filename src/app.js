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

// Add this POST endpoint after your existing GET /api/products route

// POST endpoint to create a new product
app.post('/api/products', async (req, res) => {
  try {
    const { name, price, description } = req.body;

    // Validate required fields
    if (!name || !price) {
      return res.status(400).json({
        success: false,
        error: 'Name and price are required fields'
      });
    }

    // Validate price is a number
    if (isNaN(price) || price < 0) {
      return res.status(400).json({
        success: false,
        error: 'Price must be a valid positive number'
      });
    }

    // Create new product in MongoDB
    const newProduct = new Product({
      name: name.trim(),
      price: parseFloat(price),
      description: description ? description.trim() : ''
    });

    const savedProduct = await newProduct.save();
    console.log('✅ Product created in MongoDB:', savedProduct._id);

    // Update Redis cache
    const cacheKey = 'products';
    if (redisClient && redisClient.isReady) {
      try {
        // Get all products from database (including the new one)
        const allProducts = await Product.find({});
        
        // Update the cache with all products
        await redisClient.set(cacheKey, JSON.stringify(allProducts), { EX: 3600 });
        console.log('✅ Redis cache updated with new product');
      } catch (redisError) {
        console.error('❌ Redis cache update error:', redisError.message);
        // Continue without cache update - product was still saved to DB
      }
    } else {
      console.log('⚠️ Redis not available - cache not updated');
    }

    // Return success response
    res.status(201).json({
      success: true,
      data: savedProduct,
      message: 'Product created successfully'
    });

  } catch (error) {
    console.error('❌ Error creating product:', error);
    
    // Handle MongoDB validation errors
    if (error.name === 'ValidationError') {
      return res.status(400).json({
        success: false,
        error: 'Validation error: ' + error.message
      });
    }

    // Handle duplicate key errors
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        error: 'Product with this name already exists'
      });
    }

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
