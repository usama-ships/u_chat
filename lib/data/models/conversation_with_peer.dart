import '../../core/database/app_database.dart';

/// A conversation row joined with its peer, as shown in the home list and
/// the chat header.
class ConversationWithPeer {
  const ConversationWithPeer({required this.conversation, required this.peer});

  final Conversation conversation;
  final Peer peer;
}
