const express = require('express');
const router = express.Router();
const Note = require('../models/Note');
const { protect } = require('../middleware/authMiddleware');

// @route   POST /api/notes/sync
// @desc    Sync notes (Push local changes + Pull server changes)
// @access  Private
router.post('/sync', protect, async (req, res) => {
    const { changes, lastSyncTimestamp } = req.body;
    const userId = req.user.id;

    // 1. PUSH: Apply Client Changes to DB
    if (changes && changes.length > 0) {
        const bulkOps = changes.map(note => {
            return {
                updateOne: {
                    filter: { localId: note.localId, user: userId },
                    update: {
                        $set: {
                            content: note.content,
                            version: note.version,
                            isDeleted: note.isDeleted,
                            updatedAt: new Date() // Server time is truth
                        },
                        $setOnInsert: {
                            localId: note.localId,
                            user: userId,
                            createdAt: new Date()
                        }
                    },
                    upsert: true
                }
            };
        });

        if (bulkOps.length > 0) {
            await Note.bulkWrite(bulkOps);
        }
    }

    // 2. PULL: Get Updates from Server
    // Fetch notes modified AFTER the last sync time
    let query = { user: userId };

    if (lastSyncTimestamp) {
        query.updatedAt = { $gt: new Date(lastSyncTimestamp) };
    }

    const pulledNotes = await Note.find(query);

    // 3. Return Response
    res.json({
        changes: pulledNotes,
        serverTime: new Date().toISOString()
    });
});

// @route   GET /api/notes
// @desc    Get all notes (Debugger/Fallback)
// @access  Private
router.get('/', protect, async (req, res) => {
    const notes = await Note.find({ user: req.user.id, isDeleted: false });
    res.json(notes);
});

module.exports = router;
