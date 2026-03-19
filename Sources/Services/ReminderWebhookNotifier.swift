import Foundation

actor ReminderWebhookNotifier {
    static let shared = ReminderWebhookNotifier()

    func sendDueReminder(title: String, scheduleText: String) async {
        let message = makeDueMessage(title: title, scheduleText: scheduleText)

        let weComURL = ReminderPreferenceStorage.weComWebhookURL()
        if !weComURL.isEmpty {
            _ = await sendWeComMessage(message, urlString: weComURL)
        }

        let feishuURL = ReminderPreferenceStorage.feishuWebhookURL()
        if !feishuURL.isEmpty {
            _ = await sendFeishuMessage(message, urlString: feishuURL)
        }
    }

    private func makeDueMessage(title: String, scheduleText: String) -> String {
        """
        RemindersMac 提醒到点
        事项：\(title)
        时间：\(scheduleText)
        """
    }

    private func sendWeComMessage(_ message: String, urlString: String) async -> Bool {
        let payload: [String: Any] = [
            "msgtype": "text",
            "text": [
                "content": message,
            ],
        ]
        return await sendRequest(
            channelName: "企微",
            urlString: urlString,
            payload: payload
        ) { data in
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }
            return (json["errcode"] as? Int) == 0
        }
    }

    private func sendFeishuMessage(_ message: String, urlString: String) async -> Bool {
        let payload: [String: Any] = [
            "msg_type": "text",
            "content": [
                "text": message,
            ],
        ]
        return await sendRequest(
            channelName: "飞书",
            urlString: urlString,
            payload: payload
        ) { data in
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }
            return (json["code"] as? Int) == 0 || (json["StatusCode"] as? Int) == 0
        }
    }

    private func sendRequest(
        channelName: String,
        urlString: String,
        payload: [String: Any],
        isSuccess: (Data) -> Bool
    ) async -> Bool {
        guard let url = URL(string: urlString),
              let body = try? JSONSerialization.data(withJSONObject: payload)
        else {
            NSLog("[Webhook] %@ URL 无效，发送跳过", channelName)
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

            guard statusCode == 200, isSuccess(data) else {
                let responseBody = String(data: data, encoding: .utf8) ?? "<empty>"
                NSLog("[Webhook] %@ 发送失败，HTTP=%ld，响应=%@", channelName, statusCode, responseBody)
                return false
            }

            NSLog("[Webhook] %@ 发送成功", channelName)
            return true
        } catch {
            NSLog("[Webhook] %@ 发送异常: %@", channelName, error.localizedDescription)
            return false
        }
    }
}
