const express = require("express");
const http = require("http");
const socketIo = require("socket.io");
const cors = require("cors");
const helmet = require("helmet");
const crypto = require('crypto');
require("dotenv").config();

// ZEGOCLOUD App credentials - MOVED TO ENVIRONMENT VARIABLES FOR SECURITY
const APP_ID = parseInt(process.env.ZEGO_APP_ID);
const SERVER_SECRET = process.env.ZEGO_SERVER_SECRET;

// Validate required environment variables
if (!APP_ID || !SERVER_SECRET) {
  console.error('❌ CRITICAL ERROR: ZEGO_APP_ID and ZEGO_SERVER_SECRET environment variables are required!');
  console.error('Please set these environment variables before starting the server:');
  console.error('  export ZEGO_APP_ID=your_app_id');
  console.error('  export ZEGO_SERVER_SECRET=your_server_secret');
  process.exit(1);
}

// ZEGOCLOUD Token Generator Functions
function generateToken(userID, effectiveTimeInSeconds = 86400) {
  if (!userID) {
    throw new Error('userID is required');
  }

  const payload = {
    iss: APP_ID,
    exp: Math.floor(Date.now() / 1000) + effectiveTimeInSeconds,
    userId: userID,
    iat: Math.floor(Date.now() / 1000),
  };

  const header = {
    alg: 'HS256',
    typ: 'JWT'
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));

  const signature = crypto
    .createHmac('sha256', SERVER_SECRET)
    .update(`${encodedHeader}.${encodedPayload}`)
    .digest('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');

  return `${encodedHeader}.${encodedPayload}.${signature}`;
}

function base64UrlEncode(str) {
  return Buffer.from(str)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

function validateToken(token) {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return false;

    const payload = JSON.parse(Buffer.from(parts[1], 'base64').toString());
    const now = Math.floor(Date.now() / 1000);
    
    return payload.exp > now && payload.iss === APP_ID;
  } catch (error) {
    return false;
  }
}

const app = express();
const server = http.createServer(app);

// Configure CORS securely
const allowedOrigins = process.env.ALLOWED_ORIGINS 
  ? process.env.ALLOWED_ORIGINS.split(',')
  : ['http://localhost:3000', 'http://localhost:8080']; // Development defaults

const corsOptions = {
  origin: function (origin, callback) {
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin) return callback(null, true);
    
    if (allowedOrigins.indexOf(origin) !== -1 || process.env.NODE_ENV === 'development') {
      callback(null, true);
    } else {
      console.warn(`🚨 CORS blocked request from origin: ${origin}`);
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST'],
  allowedHeaders: ['Content-Type', 'Authorization']
};

// Configure CORS for Socket.IO
const io = socketIo(server, {
  cors: corsOptions,
});

// Rate limiting configuration
const rateLimit = require("express-rate-limit");

// General API rate limiting
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: {
    error: "Too many requests from this IP, please try again later.",
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Token generation rate limiting (more restrictive)
const tokenLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 10, // Limit each IP to 10 token requests per minute
  message: {
    error: "Too many token requests, please try again later.",
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));
app.use(cors(corsOptions));
app.use(express.json({ limit: '10mb' }));
app.use(generalLimiter);

// Request logging middleware
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path} - IP: ${req.ip}`);
  next();
});

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({ status: "OK", timestamp: new Date().toISOString() });
});

// Input validation functions
function isValidUserId(userId) {
  return typeof userId === 'string' && 
         userId.length > 0 && 
         userId.length <= 64 && 
         /^[a-zA-Z0-9_-]+$/.test(userId);
}

function isValidRoomId(roomId) {
  return typeof roomId === 'string' && 
         roomId.length > 0 && 
         roomId.length <= 128 && 
         /^[a-zA-Z0-9_-]+$/.test(roomId);
}

function sanitizeString(str) {
  return str.replace(/[<>\"'&]/g, '');
}

// ZEGOCLOUD token generation endpoint with enhanced security
app.post("/zego-token", tokenLimiter, (req, res) => {
  try {
    const { userId, roomId } = req.body;

    // Enhanced input validation
    if (!userId || !roomId) {
      console.warn(`❌ Token request missing required fields - IP: ${req.ip}`);
      return res.status(400).json({
        error: "userId and roomId are required",
        code: "MISSING_REQUIRED_FIELDS"
      });
    }

    // Validate userId format and length
    if (!isValidUserId(userId)) {
      console.warn(`❌ Invalid userId format: "${userId}" - IP: ${req.ip}`);
      return res.status(400).json({
        error: "Invalid userId format. Must be alphanumeric with underscores/hyphens, max 64 characters",
        code: "INVALID_USER_ID"
      });
    }

    // Validate roomId format and length
    if (!isValidRoomId(roomId)) {
      console.warn(`❌ Invalid roomId format: "${roomId}" - IP: ${req.ip}`);
      return res.status(400).json({
        error: "Invalid roomId format. Must be alphanumeric with underscores/hyphens, max 128 characters",
        code: "INVALID_ROOM_ID"
      });
    }

    // Sanitize inputs
    const cleanUserId = sanitizeString(userId);
    const cleanRoomId = sanitizeString(roomId);

    // Generate token (valid for 24 hours)
    const token = generateToken(cleanUserId, 86400);

    console.log(`✅ Generated ZEGO token for user ${cleanUserId} in room ${cleanRoomId} - IP: ${req.ip}`);

    res.json({
      token,
      userId: cleanUserId,
      roomId: cleanRoomId,
      expiresIn: 86400, // 24 hours in seconds
      generatedAt: new Date().toISOString()
    });
  } catch (error) {
    console.error(`❌ Error generating ZEGO token - IP: ${req.ip}:`, error);
    
    // Don't expose internal error details to client
    res.status(500).json({
      error: "Internal server error while generating token",
      code: "TOKEN_GENERATION_FAILED"
    });
  }
});

// Token validation endpoint with security improvements
app.post("/zego-token/validate", tokenLimiter, (req, res) => {
  try {
    const { token } = req.body;

    // Input validation
    if (!token) {
      console.warn(`❌ Token validation request missing token - IP: ${req.ip}`);
      return res.status(400).json({
        error: "token is required",
        code: "MISSING_TOKEN"
      });
    }

    // Validate token format (basic JWT structure check)
    if (typeof token !== 'string' || !token.includes('.')) {
      console.warn(`❌ Invalid token format - IP: ${req.ip}`);
      return res.status(400).json({
        error: "Invalid token format",
        code: "INVALID_TOKEN_FORMAT"
      });
    }

    // Validate token length (prevent extremely long tokens)
    if (token.length > 2048) {
      console.warn(`❌ Token too long - IP: ${req.ip}`);
      return res.status(400).json({
        error: "Token too long",
        code: "TOKEN_TOO_LONG"
      });
    }

    const isValid = validateToken(token);

    console.log(`🔍 Token validation result: ${isValid ? 'VALID' : 'INVALID'} - IP: ${req.ip}`);

    res.json({
      valid: isValid,
      validatedAt: new Date().toISOString()
    });
  } catch (error) {
    console.error(`❌ Error validating ZEGO token - IP: ${req.ip}:`, error);
    
    // Don't expose internal error details
    res.status(500).json({
      error: "Internal server error while validating token",
      code: "TOKEN_VALIDATION_FAILED"
    });
  }
});

// Store active sessions and participants
const sessions = new Map();
const participants = new Map();

io.on("connection", (socket) => {
  console.log(`Client connected: ${socket.id}`);

  // Join a therapy session
  socket.on("join-session", (data) => {
    const { sessionId, participantId, participantName } = data;

    console.log(
      `${participantName} (${participantId}) joining session ${sessionId}`
    );

    // Store participant info
    participants.set(socket.id, {
      id: participantId,
      name: participantName,
      sessionId,
      socketId: socket.id,
    });

    // Join socket room
    socket.join(sessionId);

    // Initialize session if doesn't exist
    if (!sessions.has(sessionId)) {
      sessions.set(sessionId, {
        id: sessionId,
        participants: new Map(),
        createdAt: new Date(),
      });
    }

    const session = sessions.get(sessionId);
    session.participants.set(participantId, {
      id: participantId,
      name: participantName,
      socketId: socket.id,
      joinedAt: new Date(),
    });

    // Notify participant they joined successfully
    socket.emit("session-joined", {
      sessionId,
      participantId,
      participantCount: session.participants.size,
    });

    // If two participants, notify both that partner is available
    if (session.participants.size === 2) {
      const participantList = Array.from(session.participants.values());
      const partner = participantList.find((p) => p.id !== participantId);

      // Notify current participant about partner
      socket.emit("partner-connected", {
        partnerId: partner.id,
        partnerName: partner.name,
      });

      // Notify partner about current participant
      socket.to(partner.socketId).emit("partner-connected", {
        partnerId: participantId,
        partnerName: participantName,
      });

      console.log(`Session ${sessionId} is ready with both partners`);
    }
  });

  // WebRTC signaling: offer
  socket.on("offer", (data) => {
    const { sessionId, targetId, offer } = data;
    const participant = participants.get(socket.id);

    if (!participant) return;

    console.log(
      `Offer from ${participant.id} to ${targetId} in session ${sessionId}`
    );

    // Find target participant's socket
    const session = sessions.get(sessionId);
    if (session) {
      const target = session.participants.get(targetId);
      if (target) {
        socket.to(target.socketId).emit("offer", {
          fromId: participant.id,
          fromName: participant.name,
          offer,
        });
      }
    }
  });

  // WebRTC signaling: answer
  socket.on("answer", (data) => {
    const { sessionId, targetId, answer } = data;
    const participant = participants.get(socket.id);

    if (!participant) return;

    console.log(
      `Answer from ${participant.id} to ${targetId} in session ${sessionId}`
    );

    // Find target participant's socket
    const session = sessions.get(sessionId);
    if (session) {
      const target = session.participants.get(targetId);
      if (target) {
        socket.to(target.socketId).emit("answer", {
          fromId: participant.id,
          fromName: participant.name,
          answer,
        });
      }
    }
  });

  // WebRTC signaling: ICE candidate
  socket.on("ice-candidate", (data) => {
    const { sessionId, targetId, candidate } = data;
    const participant = participants.get(socket.id);

    if (!participant) return;

    // Find target participant's socket
    const session = sessions.get(sessionId);
    if (session) {
      const target = session.participants.get(targetId);
      if (target) {
        socket.to(target.socketId).emit("ice-candidate", {
          fromId: participant.id,
          candidate,
        });
      }
    }
  });

  // Session end
  socket.on("end-session", (data) => {
    const { sessionId } = data;
    const participant = participants.get(socket.id);

    if (!participant) return;

    console.log(`${participant.name} ending session ${sessionId}`);

    // Notify partner
    socket.to(sessionId).emit("partner-disconnected", {
      partnerId: participant.id,
      partnerName: participant.name,
    });

    // Clean up
    handleDisconnect(socket);
  });

  // Handle disconnection
  socket.on("disconnect", () => {
    console.log(`Client disconnected: ${socket.id}`);
    handleDisconnect(socket);
  });

  function handleDisconnect(socket) {
    const participant = participants.get(socket.id);

    if (participant) {
      const { sessionId, id: participantId, name } = participant;

      // Remove from session
      const session = sessions.get(sessionId);
      if (session) {
        session.participants.delete(participantId);

        // Notify remaining participants
        socket.to(sessionId).emit("partner-disconnected", {
          partnerId: participantId,
          partnerName: name,
        });

        // Clean up empty sessions
        if (session.participants.size === 0) {
          sessions.delete(sessionId);
          console.log(
            `Session ${sessionId} deleted - no participants remaining`
          );
        }
      }

      // Remove participant
      participants.delete(socket.id);
    }
  }
});

// Cleanup old sessions (run every hour)
setInterval(() => {
  const now = new Date();
  const maxAge = 24 * 60 * 60 * 1000; // 24 hours

  for (const [sessionId, session] of sessions.entries()) {
    if (now - session.createdAt > maxAge && session.participants.size === 0) {
      sessions.delete(sessionId);
      console.log(`Cleaned up old session: ${sessionId}`);
    }
  }
}, 60 * 60 * 1000);

const PORT = process.env.PORT || 3000;
server.listen(PORT, "0.0.0.0", () => {
  console.log(`Mend signaling server running on port ${PORT}`);
  console.log(`Health check available at: http://localhost:${PORT}/health`);
});

// Graceful shutdown
process.on("SIGTERM", () => {
  console.log("SIGTERM received, shutting down gracefully");
  server.close(() => {
    console.log("Server closed");
    process.exit(0);
  });
});
