#!/bin/bash
## MongoDB Initialization Script
## Place in ./mongodb/init/ directory (make executable with chmod +x)

set -e # Exit on any error

# Read application password from Docker secret
APP_PASSWORD=$(cat /run/secrets/mongodb_app_password)

# Execute MongoDB initialization commands
mongosh --quiet <<EOF
// Switch to products database
db = db.getSiblingDB('products');

// Create application user with proper permissions
db.createUser({
  user: "app_user",
  pwd: "$APP_PASSWORD",
  roles: [
    { role: "readWrite", db: "products" },
    { role: "dbAdmin", db: "products" }
  ]
});

// Collection creation
db.createCollection("products");
db.createCollection("categories");
db.createCollection("users");
db.createCollection("orders");

// Indexes for optimal query performance
db.products.createIndexes([
  { "name": 1 },
  { "category": 1 },
  { "price": 1 },
  { "createdAt": -1 }
]);

db.categories.createIndex({ "name": 1 }, { unique: true });

db.users.createIndexes([
  { "email": 1, unique: true },
  { "username": 1, unique: true }
]);

db.orders.createIndexes([
  { "userId": 1 },
  { "status": 1 },
  { "createdAt": -1 }
]);

// Sample data insertion
var categories = db.categories.insertMany([
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

var electronicsId = db.categories.findOne({name: "Electronics"})._id;
var booksId = db.categories.findOne({name: "Books"})._id;
var clothingId = db.categories.findOne({name: "Clothing"})._id;

db.products.insertMany([
  {
    _id: ObjectId(),
    name: "Smartphone",
    description: "High-end smartphone with excellent camera",
    price: 699.99,
    category: electronicsId,
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
    category: booksId,
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
    category: clothingId,
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

// Test user insertion
db.users.insertOne({
  _id: ObjectId(),
  username: "testuser",
  email: "test@example.com",
  firstName: "Test",
  lastName: "User",
  hashedPassword: "$2b\$10\$example_hashed_password",
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

// Test order creation
var testUser = db.users.findOne({username: "testuser"});
var smartphone = db.products.findOne({name: "Smartphone"});

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

EOF

echo "✅ Database initialization completed successfully!"
