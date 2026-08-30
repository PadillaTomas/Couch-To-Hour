#if DEBUG
import Foundation
import SwiftData
import UIKit

/// DEBUG-only: put the app into a realistic mid-plan state so the Calendar and
/// Today have data to click through, without running sessions by hand.
///
/// It goes through the **same functions a real setup / session uses**
/// (`OnboardingCompletion.apply`, `DoneDetection.markComplete`, `PhotoStore`) —
/// the only thing "demo" about it is that it's seeded in one shot and only
/// exists in DEBUG builds. Nothing here writes data a real run couldn't.
enum DemoData {

    /// A fully populated **3-Day** state: the schedule is anchored ~2.5 weeks in
    /// the past, so the Calendar shows completed sessions behind and scheduled
    /// sessions ahead, with "today" landing around Week 3. A couple of the past
    /// sessions carry a photo.
    static func loadThreeDay(into context: ModelContext, now: Date = .now) {
        guard let plan = try? context.fetch(FetchDescriptor<WorkoutPlan>()).first else { return }
        clear(from: context)

        let calendar = Calendar.current
        let anchor = calendar.date(byAdding: .day, value: -18, to: calendar.startOfDay(for: now))!

        // Real setup path — stamps planEpoch, startDate, the onboarding gate, etc.
        OnboardingCompletion.apply(
            PlanSetup(mode: .threeDay, startingWeek: 1, startDate: anchor),
            now: anchor, in: context, calendar: calendar)

        let schedule = ScheduleGenerator.schedule(startingWeek: 1, startDate: anchor, calendar: calendar)
        let ratings = [5, 6, 5, 7, 6, 8, 6, 7, 6, 7]

        for (index, slot) in schedule.enumerated()
        where slot.date < calendar.startOfDay(for: now) {
            guard let day = plan.day(week: slot.week, day: slot.day) else { continue }
            let record = DoneDetection.markComplete(
                day, on: slot.date,
                feltRating: ratings[index % ratings.count],
                calendar: calendar, in: context)
            // Two of the earlier sessions get a photo — same PhotoStore path a
            // user's pick takes.
            if (slot.week == 1 && slot.day == 2) || (slot.week == 2 && slot.day == 2) {
                record?.photoPath = try? PhotoStore.save(sampleImage())
            }
        }
        context.saveChanges("demo data")
    }

    static func clear(from context: ModelContext) {
        for record in (try? context.fetch(FetchDescriptor<CompletionRecord>())) ?? [] {
            if let photo = record.photoPath { PhotoStore.delete(photo) }
            context.delete(record)
        }
        try? context.save()
    }

    /// A stand-in "workout photo", generated so there's no asset to ship. It's
    /// written and read back through `PhotoStore` exactly like a real pick.
    private static func sampleImage() -> UIImage {
        let size = CGSize(width: 1200, height: 900)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [UIColor(red: 0.77, green: 0.44, blue: 0.24, alpha: 1).cgColor,
                         UIColor(red: 0.20, green: 0.28, blue: 0.30, alpha: 1).cgColor] as CFArray,
                locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(
                gradient, start: .zero,
                end: CGPoint(x: size.width, y: size.height), options: [])

            let text = "DEMO" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 140, weight: .heavy),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85),
            ]
            let textSize = text.size(withAttributes: attrs)
            text.draw(at: CGPoint(x: (size.width - textSize.width) / 2,
                                  y: (size.height - textSize.height) / 2),
                      withAttributes: attrs)
        }
    }
}
#endif
