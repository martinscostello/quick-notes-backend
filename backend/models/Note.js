const mongoose = require('mongoose');

const NoteSchema = new mongoose.Schema({
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },

    // Core Data
    localId: { type: String, required: true }, // ID from the Client (UUID)
    content: { type: String, default: "" }, // Markdown/HTML content

    // Sync Metadata
    version: { type: Number, default: 1 },
    isDeleted: { type: Boolean, default: false },
    lastModified: { type: Date, default: Date.now },

    // Assets (Images uploaded to S3)
    attachments: [{
        localId: String,
        url: String
    }]
}, { timestamps: true });

// Create Index for Syncing
NoteSchema.index({ user: 1, lastModified: -1 });

module.exports = mongoose.model('Note', NoteSchema);
