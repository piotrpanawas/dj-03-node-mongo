// MongoDB initialization script for products database
// This script runs automatically when MongoDB container starts for the first time
// Place this file in ./mongodb/init/ directory

// Switch to the products database
db = db.getSiblingDB('products');

// Read the app password from the mounted secret
var appPassword = cat('/run/secrets/mongodb_app_password');

// Create application user with readWrite permissions
db.createUser({
  user: "app_user",
  pwd: appPassword.trim(),
  roles: [
    {
      role: "readWrite",
      db: "products"
    },
    {
      role: "dbAdmin",
      db: "products"
    }
  ]
});

// Create initial collections with indexes
db.createCollection("products");
db.createCollection("categories");
db.createCollection("users");
db.createCollection("orders");

// Create indexes for better performance
db.products.createIndex({ "name": 1 });
db.products.createIndex({ "category": 1 });
db.products.createIndex({ "price": 1 });
db.products.createIndex({ "createdAt": -1 });

db.categories.createIndex({ "name": 1 }, { unique: true });

db.users.createIndex({ "email": 1 }, { unique: true });
db.users.createIndex({ "username": 1 }, { unique: true });

db.orders.createIndex({ "userId": 1 });
db.orders.createIndex({ "status": 1 });
db.orders.createIndex({ "createdAt": -1 });

// Insert sample data for testing
db.categories.insertMany([
  {
    _id: ObjectId(),
    name: "Electronics",
    description: "Electronic devices and gadgets",
    createdAt: new Date()
  },
  {
    _id: ObjectId(),
    name: "Books",
    description: "Books and literature",
    createdAt: new Date()
  },
  {
    _id: ObjectId(),
    name: "Clothing",
    description: "Apparel and accessories",
    createdAt: new Date()
  }
]);

// Get category IDs for product insertion
var electronicsCategory = db.categories.findOne({ name: "Electronics" })._id;
var booksCategory = db.categories.findOne({ name: "Books" })._id;
var clothingCategory = db.categories.findOne({ name: "Clothing" })._id;

// Insert sample products
db.products.insertMany([
  {
    _id: ObjectId(),
    name: "Smartphone",
    description: "High-end smartphone with excellent camera",
    price: 699.99,
    category: electronicsCategory,
    inStock: true,
    quantity: 50,
    tags: ["electronics", "mobile", "communication"],
    specifications: {
      brand: "TechCorp",
      model: "TC-2024",
      color: "Black",
      storage: "128GB"
    },
    createdAt: new Date(),
    updatedAt: new Date()
  },
  {
    _id: ObjectId(),
    name: "Programming Fundamentals",
    description: "Complete guide to programming fundamentals",
    price: 49.99,
    category: booksCategory,
    inStock: true,
    quantity: 100,
    tags: ["book", "programming", "education"],
    specifications: {
      author: "Jane Developer",
      pages: 450,
      publisher: "Tech Books",
      isbn: "978-1234567890"
    },
    createdAt: new Date(),
    updatedAt: new Date()
  },
  {
    _id: ObjectId(),
    name: "Cotton T-Shirt",
    description: "Comfortable cotton t-shirt for casual wear",
    price: 19.99,
    category: clothingCategory,
    inStock: true,
    quantity: 200,
    tags: ["clothing", "casual", "cotton"],
    specifications: {
      material: "100% Cotton",
      sizes: ["S", "M", "L", "XL"],
      colors: ["White", "Black", "Navy"]
    },
    createdAt: new Date(),
    updatedAt: new Date()
  }
]);

// Insert sample user for testing
db.users.insertOne({
  _id: ObjectId(),
  username: "testuser",
  email: "test@example.com",
  firstName: "Test",
  lastName: "User",
  hashedPassword: "$2b$10$example_hashed_password",
  role: "user",
  isActive: true,
  profile: {
    phone: "+1-555-0123",
    address: {
      street: "123 Test Street",
      city: "Test City",
      state: "TS",
      zipCode: "12345",
      country: "USA"
    }
  },
  preferences: {
    notifications: true,
    newsletter: false
  },
  createdAt: new Date(),
  updatedAt: new Date()
});

// Create a test order
var testUser = db.users.findOne({ username: "testuser" });
var smartphone = db.products.findOne({ name: "Smartphone" });

db.orders.insertOne({
  _id: ObjectId(),
  userId: testUser._id,
  orderNumber: "ORD-2024-001",
  status: "completed",
  items: [
    {
      productId: smartphone._id,
      productName: smartphone.name,
      quantity: 1,
      unitPrice: smartphone.price,
      totalPrice: smartphone.price
    }
  ],
  summary: {
    subtotal: smartphone.price,
    tax: smartphone.price * 0.08,
    shipping: 9.99,
    total: smartphone.price + (smartphone.price * 0.08) + 9.99
  },
  shippingAddress: testUser.profile.address,
  paymentMethod: "credit_card",
  paymentStatus: "paid",
  createdAt: new Date(),
  updatedAt: new Date(),
  shippedAt: new Date(),
  deliveredAt: new Date()
});

// Log successful initialization
print("MongoDB products database initialized successfully!");
print("Created collections: products, categories, users, orders");
print("Created application user: app_user");
print("Inserted sample data for testing");
print("Database is ready for use!");