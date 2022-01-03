import 'dart:convert';

import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/cutil/client_components.dart';
import 'package:mildly_encrypted_package/src/client/cutil/notification_registry.dart';
import 'package:mildly_encrypted_package/src/client/data/message_storage.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';

class ReactionHandler implements MessageHandler {
  @override
  bool check(String message, String from, {String? keyID}) {
    //we need a message id to update, and a message update value
    return JSONValidate.isValidJSON(message,
            requiredKeys: [ClientComponent.ADD_REACTION]) ||
        JSONValidate.isValidJSON(message,
            requiredKeys: [ClientComponent.REMOVE_REACTION]);
  }

  @override
  String getHandlerName() {
    return "Reaction Message Update Event";
  }

  Future<void> removeAnyExistingReactionsFromUser(
      String from, String messageUuid,
      {String? keyID}) async {
    String serverIP = EncryptedClient.getInstance()!.serverUrl;
    String chatID = keyID ?? from;
    Map? currentMessageData = await MessageStorage().getMessage<Map>(
        serverIP,
        chatID,
        messageUuid,
        (
                {required data,
                required messageContent,
                required messageUuid,
                required sender,
                required time}) =>
            data);
    if (currentMessageData == null) {
      ELog.e(
          "Received update request for a message that does not exist. $from > $messageUuid");
      return;
    }
    Map reactions = {};
    if (currentMessageData.containsKey('reactions')) {
      reactions = currentMessageData['reactions'];
    }
    if (reactions.containsKey(from)) {
      reactions.remove(from);
    }
    currentMessageData['reactions'] = reactions;

    await MessageStorage()
        .updateMessage(serverIP, chatID, messageUuid, currentMessageData);
  }

  Future<void> addNewReaction(String from, String messageUuid, String reaction,
      {String? keyID}) async {
    String serverIP = EncryptedClient.getInstance()!.serverUrl;
    String chatID = keyID ?? from;
    Map? currentMessageData = await MessageStorage().getMessage<Map>(
        serverIP,
        chatID,
        messageUuid,
        (
                {required data,
                required messageContent,
                required messageUuid,
                required sender,
                required time}) =>
            data);
    if (currentMessageData == null) {
      ELog.e(
          "Received update request for a message that does not exist. $from > $messageUuid");
      return;
    }
    Map reactions = {};
    if (currentMessageData.containsKey('reactions')) {
      reactions = currentMessageData['reactions'];
    }
    reactions[from] = reaction;
    currentMessageData['reactions'] = reactions;
    await MessageStorage()
        .updateMessage(serverIP, chatID, messageUuid, currentMessageData);
  }

  @override
  Future<void> handle(String message, String from, {String? keyID}) async {
    Map map = jsonDecode(message);
    String messageUuid = map[ClientComponent.MESSAGE_UUID];

    if (map.containsKey(ClientComponent.ADD_REACTION)) {
      String reaction = map[ClientComponent.ADD_REACTION];
      await removeAnyExistingReactionsFromUser(from, messageUuid, keyID: keyID);
      await addNewReaction(from, messageUuid, reaction, keyID: keyID);
    } else if (map.containsKey(ClientComponent.REMOVE_REACTION)) {
      String reaction = map[ClientComponent.REMOVE_REACTION];
      await removeAnyExistingReactionsFromUser(from, messageUuid, keyID: keyID);
    }
    if(keyID != null){
      UpdateNotificationRegistry.getInstance().messageUpdate((await ClientManagement.getInstance().getGroupChat(keyID))!, messageUuid);
    }
    else{
      UpdateNotificationRegistry.getInstance().messageUpdate((await ClientManagement.getInstance().getUser(from))!, messageUuid);
    }
  }
}