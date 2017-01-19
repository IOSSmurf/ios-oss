import Library
import LiveStream
import Prelude
import UIKit

internal final class LiveStreamDiscoveryDataSource: ValueCellDataSource {

  internal func load(liveStreams: [LiveStreamEvent]) {

    self.clearValues()

    let sortedLiveStreams = sorted(liveStreamEvents: liveStreams)
    sortedLiveStreams
      .enumerated()
      .forEach { idx, stream in

        if idx == 0 {
          self.appendRow(value: titleThatImmediatelyPrecedes(liveStreamEvent: stream),
                         cellClass: LiveStreamDiscoveryTitleCell.self,
                         toSection: 0)
        } else {
          let previousStream = sortedLiveStreams[idx - 1]
          let title = titleThatImmediatelyPrecedes(liveStreamEvent: stream)
          let previousTitle = titleThatImmediatelyPrecedes(liveStreamEvent: previousStream)

          if title != previousTitle {
            self.appendRow(value: title, cellClass: LiveStreamDiscoveryTitleCell.self, toSection: 0)
          }
        }

        self.appendRow(value: stream, cellClass: LiveStreamDiscoveryCell.self, toSection: 0)
    }
  }

  internal override func configureCell(tableCell cell: UITableViewCell, withValue value: Any) {

    switch (cell, value) {
    case let (cell as LiveStreamDiscoveryCell, value as LiveStreamEvent):
      cell.configureWith(value: value)
    case let (cell as LiveStreamDiscoveryTitleCell, value as LiveStreamDiscoveryTitleType):
      cell.configureWith(value: value)
    default:
      assertionFailure("Unrecognized combo: \(cell), \(value)")
    }
  }
}

private func sorted(liveStreamEvents: [LiveStreamEvent]) -> [LiveStreamEvent] {

  let now = AppEnvironment.current.dateType.init().date 

  // Compares two live streams, putting live ones first.
  let currentlyLiveStreamsFirstComparator = Prelude.Comparator<LiveStreamEvent> { lhs, rhs in
    switch (lhs.liveNow, rhs.liveNow) {
    case (true, false):                 return .lt
    case (false, true):                 return .gt
    case (true, true), (false, false):  return .eq
    }
  }

  // Compares two live streams, putting the future ones first.
  let futureLiveStreamsFirstComparator = Prelude.Comparator<LiveStreamEvent> { lhs, rhs in
    lhs.startDate > now && rhs.startDate > now || lhs.startDate < now && rhs.startDate < now
      ? .eq : lhs.startDate < rhs.startDate ? .gt
      : .lt
  }

  // Compares two live streams, putting soon-to-be-live first and way-back past last.
  let startDateComparator = Prelude.Comparator<LiveStreamEvent> { lhs, rhs in
    lhs.startDate > now
      ? (lhs.startDate == rhs.startDate ? .eq : lhs.startDate < rhs.startDate ? .lt: .gt)
      : (lhs.startDate == rhs.startDate ? .eq : lhs.startDate < rhs.startDate ? .gt: .lt)
  }

  // Sort by:
  //   * live streams first
  //   * then future streams first and past streams last
  //   * future streams sorted by start date asc, past streams sorted by start date desc

  return liveStreamEvents.sorted(
    comparator: currentlyLiveStreamsFirstComparator
      <> futureLiveStreamsFirstComparator
      <> startDateComparator
  )
}

private func titleThatImmediatelyPrecedes(liveStreamEvent: LiveStreamEvent) -> LiveStreamDiscoveryTitleType {
  return liveStreamEvent.liveNow ? .liveNow
    : liveStreamEvent.startDate > AppEnvironment.current.dateType.init().date ? .upcoming
    : .recentlyLive
}
