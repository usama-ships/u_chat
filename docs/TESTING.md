# U Chat — Device Test Checklist

Automated tests (`flutter test`) cover the protocol, cryptography, database and
delivery logic with simulated phones. This checklist covers what only real
radios can show. You need **two Android phones** (A and B) running the same build.

Record each result as ✅ / ❌ with notes. For any ❌, run `flutter run` and copy
the lines starting with `PeerSession … closed:`.

## 1. Setup and permissions
| # | Step | Expected |
|---|---|---|
| 1.1 | Fresh install, open Nearby | "Nearby devices" permission prompt |
| 1.2 | Deny permission | "Permission needed" screen with **Allow** |
| 1.3 | Deny twice, then tap the button | Button says **Open app settings** and opens them |
| 1.4 | Bluetooth off, open Nearby | "Bluetooth is off". Turning it on starts scanning automatically |
| 1.5 | Settings → Bluetooth | Status "Ready", Visibility "Visible to nearby U Chat users…" |

## 2. Discovery
| # | Step | Expected |
|---|---|---|
| 2.1 | Open Nearby on both phones | Each lists the other within ~5 s, with name and signal |
| 2.2 | Close U Chat on B | B disappears from A's list within ~12 s |
| 2.3 | Change B's name in Settings | A shows the new name (first 13 bytes) |
| 2.4 | Leave Nearby open for 2+ minutes | Scanning stops; **Scan again** appears |

## 3. Connecting and security
| # | Step | Expected |
|---|---|---|
| 3.1 | A: tap **Connect** on B | Chat opens; header "Connected · encrypted · NN ms"; full name shown |
| 3.2 | Both tap Connect at the same moment | Exactly one connection on each side |
| 3.3 | Open the contact (tap the header) on both phones | **Same safety number** on both |
| 3.4 | Mark verified | ✓ badge in chat header, Home and contact screen |
| 3.5 | Disconnect via ⋮ | Both show "Not connected"; no auto-reconnect |
| 3.6 | B: block A; A tries to connect | A drops to "Not connected" within a second and doesn't auto-reconnect; nothing A sends reaches B |
| 3.7 | B: unblock; Settings → turn off **Accept new devices**; a third phone C (never chatted) connects | C is refused; A can still connect |

## 4. Messaging
| # | Step | Expected |
|---|---|---|
| 4.1 | Send "hi" | 🕒 → ✓ → ✓✓ within ~1 s; appears on B |
| 4.2 | Reply from B | Both sides show the full conversation in order |
| 4.3 | Send 10 messages quickly | All arrive in order, all ✓✓ |
| 4.4 | Send a ~4000-character message | Delivered intact |
| 4.5 | Emoji and non-Latin text (😀, عربي, 中文) | Delivered intact |
| 4.6 | Long-press a message | Copy, details; Retry on failed messages |
| 4.7 | B has the chat closed; A sends | B's Home shows an unread badge; opening the chat clears it |

## 5. Interruptions and recovery
| # | Step | Expected |
|---|---|---|
| 5.1 | Disconnect, send 2 messages, tap **Connect** | Both delivered automatically |
| 5.2 | Send, then immediately turn Bluetooth off on B | After ~30 s: "Not delivered · Tap to retry". Turn on, reconnect, tap: delivered |
| 5.3 | Connected from A; toggle B's Bluetooth off/on | A reconnects by itself within ~1 minute |
| 5.4 | Walk out of range (~35 s), come back | Connection drops, then A reconnects |
| 5.5 | Kill A while a message is Sending; reopen | Message is Pending, then delivered after reconnecting |
| 5.6 | Change name on A while connected | B's chat header updates immediately |

## 6. Persistence
| # | Step | Expected |
|---|---|---|
| 6.1 | Force-stop both apps, reopen | All conversations, messages and statuses intact |
| 6.2 | Reboot the phone | Same as 6.1; Device ID unchanged |
| 6.3 | Chat with 150+ messages | Newest shown first; **Load earlier messages** loads older ones |
| 6.4 | Delete a conversation (long-press on Home) | Removed; contact still verified when they reconnect |

## 7. Offline
| # | Step | Expected |
|---|---|---|
| 7.1 | Airplane mode on, then turn Bluetooth back on, on both phones | Discovery, connecting and messaging all work |
| 7.2 | No SIM / Wi-Fi at all | Same |

## 8. Background (known MVP limit)
| # | Step | Expected |
|---|---|---|
| 8.1 | Home button on B for 1 minute | B stops advertising (expected). Existing connection may survive briefly |
| 8.2 | Return to B | Advertising resumes; reconnects if needed |

## 9. Voice messages

Needs two phones, on the same version of the app.

1. Hold the mic, speak for a few seconds, release. The note appears at once with a progress ring.
2. Time a 1-minute note from release to the double tick, and note the result. This is the real transfer speed.
3. Play it on the other phone. Try 1.5× and 2×, and drag along the trace to seek.
4. Slide left while holding: nothing is sent. Slide up: recording continues without a finger, and the delete and send buttons both work.
5. Send a long note and, during the transfer, send a text. The text should arrive before the note finishes.
6. Walk out of range during a transfer, then come back. It should continue from where it stopped, not restart.
7. Deny the microphone when asked: a clear message appears and nothing records.
8. Delete the conversation: the audio goes too.
