const express = require('express');
const router = express.Router();
const multer = require('multer');
const AWS = require('aws-sdk');
const { protect } = require('../middleware/authMiddleware');
require('dotenv').config();

// Configure AWS S3
const s3 = new AWS.S3({
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    region: 'us-east-1' // Default, user can change
});

// Configure Multer (Memory Storage)
const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

// @route   POST /api/upload
// @desc    Upload image to S3 and return URL
// @access  Private
router.post('/', protect, upload.single('image'), (req, res) => {
    const file = req.file;
    if (!file) {
        return res.status(400).json({ message: 'No file uploaded' });
    }

    const fileName = `${Date.now()}_${file.originalname}`;

    // S3 Upload Parameters
    const params = {
        Bucket: process.env.AWS_BUCKET_NAME,
        Key: fileName,
        Body: file.buffer,
        ContentType: file.mimetype,
        ACL: 'public-read' // Make file public so Mobile app can read it (or use signed URLs)
    };

    s3.upload(params, (err, data) => {
        if (err) {
            console.error(err);
            return res.status(500).json({ message: 'S3 Upload Error', error: err });
        }
        res.json({ url: data.Location });
    });
});

module.exports = router;
