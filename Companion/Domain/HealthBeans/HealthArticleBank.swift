import Foundation

struct HealthBeanLedgerEntry: Codable, Identifiable, Equatable {
    let id: String
    let date: Date
    let title: String
    /// 正数为获得，负数为消耗
    let amount: Int
    let balanceAfter: Int
}

struct HealthArticle: Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String
    let body: String
}

enum HealthArticleBank {
    static let articles: [HealthArticle] = [
        HealthArticle(
            id: "hydrate",
            title: "化疗期间如何科学补水？",
            summary: "了解每日饮水量建议与电解质补充要点。",
            body: """
            治疗期间保持充足水分有助于代谢与缓解部分不适。一般成人可参考每日 1500–2000ml，并按医嘱调整。

            若出现明显腹泻、呕吐或少尿，应优先联系医护，必要时补充口服补液盐。避免一次性大量灌水，可少量多次饮用温水或清淡汤水。

            以上为一般健康教育信息，个体方案请遵医嘱。
            """
        ),
        HealthArticle(
            id: "fever",
            title: "发热时该如何观察与就医？",
            summary: "体温监测、危险信号与何时急诊。",
            body: """
            建议规律测量体温并记录。若持续高热、寒战、意识改变、呼吸困难，请尽快就医或拨打 120。

            退热药物需按说明书或医嘱使用，勿自行叠加多种同类药物。同时注意休息与补水。

            以上为一般健康教育信息，不能替代面诊。
            """
        ),
        HealthArticle(
            id: "diet",
            title: "治疗期饮食的基本原则",
            summary: "清淡均衡、量力进食，避免极端节食。",
            body: """
            治疗期饮食以清淡、易消化、营养均衡为宜。食欲差时可少食多餐，优先保证蛋白质与能量摄入。

            如有特殊饮食限制（如低渣、低钠），请以临床营养或医生指导为准。勿轻信偏方断食。

            以上为一般健康教育信息。
            """
        ),
        HealthArticle(
            id: "handfoot",
            title: "手足不适时的日常护理",
            summary: "护肤、避免刺激与及时反馈。",
            body: """
            出现手足红肿、脱皮或疼痛时，避免热水久泡与用力摩擦，可使用温和润肤剂，并在打卡或就诊时向医生说明。

            是否需要调整治疗方案，必须由医生评估决定。

            以上为一般健康教育信息。
            """
        ),
        HealthArticle(
            id: "record",
            title: "为什么要坚持症状打卡？",
            summary: "连续记录有助于就诊沟通。",
            body: """
            症状打卡能帮助你向医生清晰描述近期变化，例如疼痛趋势、体温波动与用药反应。

            记录不能替代检验与面诊，但能提高沟通效率。建议按提醒完成每日记录。

            以上为一般健康教育信息。
            """
        ),
        HealthArticle(
            id: "sleep",
            title: "改善睡眠质量的小建议",
            summary: "作息、环境与放松技巧。",
            body: """
            尽量固定入睡与起床时间，睡前减少咖啡因与强光屏幕。卧室保持安静、温度适宜。

            若失眠持续影响白天功能，或伴随明显焦虑抑郁，请向医生反馈，必要时寻求专业支持。

            以上为一般健康教育信息。
            """
        ),
        HealthArticle(
            id: "exercise",
            title: "康复期温和活动怎么做？",
            summary: "量力而行，循序渐进。",
            body: """
            在医生允许的前提下，可从短时散步、拉伸开始，避免过度疲劳与剧烈对抗运动。

            活动中若出现胸闷、眩晕或异常疼痛，应立即停止并评估是否需要就医。

            以上为一般健康教育信息。
            """
        ),
    ]

    /// 按日轮换，保证当天列表稳定。
    static func todayArticles(limit: Int = 5) -> [HealthArticle] {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
        var indices = Array(articles.indices)
        for i in stride(from: indices.count - 1, through: 1, by: -1) {
            let j = (day * 13 + i * 7) % (i + 1)
            indices.swapAt(i, j)
        }
        return Array(indices.prefix(min(limit, articles.count))).map { articles[$0] }
    }
}
