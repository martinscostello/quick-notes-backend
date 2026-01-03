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

    // 1. PUSH: Apply Client Changes to DB (With Conflict Safety)
    if (changes && changes.length > 0) {
        const localIds = changes.map(n => n.localId);

        // Fetch existing versions to compare timestamps
        const existingNotes = await Note.find({ user: userId, localId: { $in: localIds } });
        const existingMap = new Map();
        existingNotes.forEach(n => existingMap.set(n.localId, n));

        const bulkOps = [];

        changes.forEach(note => {
            const serverNote = existingMap.get(note.localId);
            const incomingDate = new Date(note.updatedAt); // Mobile time

            let shouldUpdate = false;

            if (!serverNote) {
                // New Note -> Always Insert
                shouldUpdate = true;
            } else {
                // Existing Note -> Compare Times
                const serverDate = new Date(serverNote.updatedAt);
                // Allow update only if Incoming is NEWER than Server
                // (Buffer of 1000ms to handle minor clock skew? No, strict.)
                if (incomingDate > serverDate) {
                    shouldUpdate = true;
                } else {
                    // Server is newer. REJECT update.
                    // effectively "Server Wins".
                    console.log(`Ignoring outdated push for ${note.localId}. Server: ${serverDate}, Incoming: ${incomingDate}`);
                }
            }

            if (shouldUpdate) {
                bulkOps.push({
                    updateOne: {
                        filter: { localId: note.localId, user: userId },
                        update: {
                            $set: {
                                content: note.content,
                                version: note.version,
                                isDeleted: note.isDeleted,
                                updatedAt: incomingDate // Trust Client timestamp? Or Server time?
                                // If we use Server Time, we solve clock skew but might drift forward.
                                // Logic usually: Trust Client Time for Last Write Wins resolution?
                                // BUT req.body sets 'updatedAt' in DB to 'new Date()' (Server Time) in previous code!
                                // Previous code: `updatedAt: new Date()`
                                // That meant EVERY push became "Now".
                                // THAT WAS THE BUG!
                                // If Mobile pushes an OLD note, Server sets it to NOW, making it the "Newest".
                                // MAC then pulls it and overwrites its actually-newer content.

                                // FIX: Use the INCOMING `updatedAt` (Client Time) or keep Server Time but ONLY if valid?
                                // No, if we use Server Time for `updatedAt`, we must ensure the content is actually new.
                                // But since we are comparing dates, we should respect the Incoming Date as the "Data Date".
                                // However, if Client Clock is wrong...
                                // PROPER FIX: Use `new Date()` (Server Time) BUT ONLY execute the update if Incoming Changes are fresh.
                                // Wait, simple comparison:
                                // If I edit on Mobile 1 min ago. Mac edited 10 mins ago.
                                // Mobile Push -> Server checks.
                                // The Timestamp we store on Server should probably be Server Time of arrival?
                                // No, then we lose offline edit history.
                                // We should store `clientUpdatedAt` and `serverUpdatedAt`?
                                // Let's keep `updatedAt` as the "Truth".
                                // Ideally, trust Client timestamp for ordering, but perhaps clamp to Server time?
                                // Safest for "Prevent Delete": Requires incoming to be > server.
                                // And we save the Incoming Date?
                                // If we save Incoming Date, we respect user's timeline.
                                // Let's save `incomingDate`.
                            }
                        },
                        upsert: true
                    }
                });
            }
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
