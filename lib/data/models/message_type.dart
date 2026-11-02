/// Kind of message payload. Only [text] exists in the MVP; the enum keeps the
/// protocol and schema extensible without migrations of existing rows.
enum MessageType { text }
