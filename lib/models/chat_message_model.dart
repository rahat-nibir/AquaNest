enum ChatSender { user, bot }

class ChatMessageModel {
  final ChatSender sender;
  final String text;
  final bool isError;

  ChatMessageModel({
    required this.sender,
    required this.text,
    this.isError = false,
  });
}
