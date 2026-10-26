//
//  NotificationService.swift
//  Notification Extension
//
//  Created by Christian Pauly on 26.08.25.
//

import Foundation
import UserNotifications
import os

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler:
            @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent =
            (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent = bestAttemptContent else { return }

        // Uncomment to read the push message payload:
        // os_log("[FluffyChatPushHelper] New message received: %{public}@", log: .default, type: .error, bestAttemptContent.userInfo)
        os_log("[FluffyChatPushHelper] New message received")

        // Check if notification contains room ID and event ID:
        guard let roomId = bestAttemptContent.userInfo["room_id"] as? String,
            let eventId = bestAttemptContent.userInfo["event_id"] as? String
        else {
            os_log("[FluffyChatPushHelper] Room ID or Event ID is missing!")
            let emptyContent = UNMutableNotificationContent()
            contentHandler(emptyContent)
            return
        }

        // Set thread identifier and fallback body:
        bestAttemptContent.body = String(
            localized: "New message - open app to read",
            comment: "Default notification body"
        )

        var unread: Int?
        if let countsJson = bestAttemptContent.userInfo["counts"] as? String,
            let counts = try? JSONDecoder().decode(
                NotificationCounts.self,
                from: countsJson.data(using: .utf8)!
            )
        {
            unread = counts.unread
        }

        // Set badge and fallback title:
        bestAttemptContent.title = String(
            localized: "\(unread ?? 1) unread messages",
            comment: "Default notification title"
        )
        if let unread = unread {
            bestAttemptContent.badge = NSNumber(integerLiteral: unread)
        }

        // Fetch the client_name:
        guard
            let devicesJson = bestAttemptContent.userInfo["devices"] as? String,
            let devices = try? JSONDecoder().decode(
                [NotificationDevice].self,
                from: devicesJson.data(using: .utf8)!
            ),
            let clientName = devices.first?.data.client_name
        else {
            bestAttemptContent.userInfo["error"] = "No client_name found in Push Notification!"
            contentHandler(bestAttemptContent)
            return
        }

        bestAttemptContent.threadIdentifier = "\(clientName)_\(roomId)"

        // Room names and avatars are cached in the App Group by the app.
        // The database itself is never shared with this extension, because iOS
        // terminates apps which are suspended while holding a lock on a shared
        // database (RUNNINGBOARD 0xdead10cc).
        guard
            let containerPath = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.pocindonesia"
            )
        else {
            os_log("[FluffyChatPushHelper] Unable to get container path!")
            contentHandler(bestAttemptContent)
            return
        }

        let cachedRoom = loadCachedRoom(
            containerPath: containerPath,
            roomId: roomId
        )

        var roomName = bestAttemptContent.userInfo["room_name"] as? String
        if roomName?.isEmpty ?? true {
            roomName = cachedRoom?.name
        }
        if roomName?.isEmpty ?? true {
            roomName = String(localized: "New chat")
        }

        if let roomName = roomName {
            bestAttemptContent.title = roomName
            bestAttemptContent.userInfo["room_name"] = roomName
        }

        if let roomAvatarUrl = cachedRoom?.avatar, !roomAvatarUrl.isEmpty {
            bestAttemptContent.userInfo["room_avatar"] = roomAvatarUrl
            do {
                let attachment = try downloadAttachment(
                    url: roomAvatarUrl,
                    containerPath: containerPath
                )
                bestAttemptContent.attachments = [attachment]
            } catch {
                os_log("[FluffyChatPushHelper] Unable to download avatar!")
            }
        }

        contentHandler(bestAttemptContent)
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler,
            let bestAttemptContent = bestAttemptContent
        {
            contentHandler(bestAttemptContent)
        }
    }

    func loadCachedRoom(containerPath: URL, roomId: String) -> NotificationRoomCache.CachedRoom? {
        let cachePath = containerPath.appendingPathComponent("notification_rooms.json")
        guard
            let data = try? Data(contentsOf: cachePath),
            let cache = try? JSONDecoder().decode(NotificationRoomCache.self, from: data)
        else {
            return nil
        }
        return cache.rooms[roomId]
    }

    func downloadAttachment(url: String, containerPath: URL) throws -> UNNotificationAttachment {
        let downloadDirectory = containerPath.appendingPathComponent("fluffychat_download_cache")

        let mxcComponents = url.replacingOccurrences(of: "mxc://", with: "").split(separator: "/")
        guard mxcComponents.count == 2 else {
            throw NSError(domain: "FamedlyPushHelper", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid MXC URL format"])
        }

        let host = String(mxcComponents[0]).replacingOccurrences(of: ".", with: "_")
        let mediaId = String(mxcComponents[1])
        let fileName = "notification_\(host)_\(mediaId).jpg"
        let fileUrl = downloadDirectory.appendingPathComponent(fileName)

        return try UNNotificationAttachment(identifier: "image", url: fileUrl, options: nil)
    }
}

struct NotificationRoomCache: Decodable {
    struct CachedRoom: Decodable {
        let name: String?
        let avatar: String?
    }
    let rooms: [String: CachedRoom]
}

struct NotificationDevice: Decodable {
    struct NotificationDeviceData: Decodable {
        let client_name: String?
    }
    let data: NotificationDeviceData
}
struct NotificationCounts: Decodable {
    let unread: Int?
}

enum DatabaseKeyError: Error { case keychain(OSStatus), invalidData }
