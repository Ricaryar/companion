import Foundation

struct HealthQuizQuestion: Identifiable, Equatable {
    let id: String
    let prompt: String
    let choices: [String]
    let correctIndex: Int
    let explanation: String
}

enum HealthQuizBank {
    /// 每日固定三题：按日期种子从题库轮换，保证同日内稳定。
    static func questionsForToday(count: Int = HealthBeansStore.quizDailyLimit, date: Date = .now) -> [HealthQuizQuestion] {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        var indices = Array(allQuestions.indices)
        // 确定性打乱
        for i in stride(from: indices.count - 1, through: 1, by: -1) {
            let j = (day * 31 + i * 17) % (i + 1)
            indices.swapAt(i, j)
        }
        return Array(indices.prefix(count)).map { allQuestions[$0] }
    }

    static let allQuestions: [HealthQuizQuestion] = [
        HealthQuizQuestion(
            id: "hydrate",
            prompt: "化疗期间若出现腹泻，以下哪项通常更合适？",
            choices: ["尽量少喝水", "按医嘱补水并及时联系医护", "自行加倍服用止泻药", "立即停用所有药物"],
            correctIndex: 1,
            explanation: "腹泻时更要关注补水与电解质，调整用药需遵医嘱，勿自行停药或加量。"
        ),
        HealthQuizQuestion(
            id: "fever",
            prompt: "治疗期间体温持续升高并伴有寒战，建议如何处理？",
            choices: ["多盖被子发汗即可", "先观察一两天再说", "尽快联系医生或就医评估", "自行加大抗生素剂量"],
            correctIndex: 2,
            explanation: "发热可能提示感染等风险，应尽快联系医生评估，勿自行调整抗生素。"
        ),
        HealthQuizQuestion(
            id: "oral",
            prompt: "口服化疗药的正确做法是？",
            choices: ["记不清就下次补服双倍", "严格按医嘱时间与剂量服用", "觉得好转就可提前停药", "与任何保健品随意同服"],
            correctIndex: 1,
            explanation: "口服药需按医嘱规律服用；漏服或合并用药请先咨询医生或药师。"
        ),
        HealthQuizQuestion(
            id: "handfoot",
            prompt: "出现手足综合征相关不适时，下列哪项更稳妥？",
            choices: ["继续用力摩擦皮肤", "按医嘱护肤并反馈给医生", "用开水长时间浸泡", "自行停用全部治疗药"],
            correctIndex: 1,
            explanation: "手足综合征需皮肤护理与及时反馈，是否调整用药应由医生决定。"
        ),
        HealthQuizQuestion(
            id: "record",
            prompt: "坚持症状打卡对就诊沟通的主要帮助是？",
            choices: ["可以完全替代面诊", "便于向医生说明近期变化", "代替所有检验检查", "证明可以自行改药"],
            correctIndex: 1,
            explanation: "连续记录有助于就诊时说清症状变化，但不能替代医生面诊与检验。"
        ),
        HealthQuizQuestion(
            id: "nutrition",
            prompt: "治疗期间饮食，哪项说法更合理？",
            choices: ["完全禁食最安全", "清淡均衡、量力进食并遵医嘱", "只吃保健品就够了", "必须大量高糖饮料冲剂"],
            correctIndex: 1,
            explanation: "以清淡均衡、可耐受的饮食为宜，特殊营养方案请遵临床营养/医嘱。"
        ),
        HealthQuizQuestion(
            id: "bleed",
            prompt: "若出现明显便血或黑便，较合适的做法是？",
            choices: ["再观察几天即可", "自行加大止血药", "尽快联系医生评估", "暂停喝水以减少排便"],
            correctIndex: 2,
            explanation: "明显便血/黑便需要及时医疗评估，勿自行加大用药或延误。"
        ),
        HealthQuizQuestion(
            id: "neuropathy",
            prompt: "出现手脚麻木等周围神经不适时，建议？",
            choices: ["继续忍耐无需告知", "在打卡中记录并向医生反馈", "自行购买止痛药大量服用", "立刻停止一切治疗"],
            correctIndex: 1,
            explanation: "周围神经症状应记录并告知医生，以便评估是否需要调整治疗。"
        ),
        HealthQuizQuestion(
            id: "appointment",
            prompt: "关于复诊与检验安排，正确的是？",
            choices: ["感觉良好就可无限推迟", "尽量按医嘱完成检验与复诊", "只看网络经验即可", "有家人意见就不必复诊"],
            correctIndex: 1,
            explanation: "检验与复诊时间请以门诊医嘱为准，有助于及时评估疗效与安全性。"
        ),
    ]
}
