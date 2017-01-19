// swiftlint:disable type_name
import Argo
import Curry
import Prelude
import Runes

public struct LiveStreamEvent: Equatable {
  public fileprivate(set) var backgroundImageUrl: String
  public fileprivate(set) var creator: Creator
  public fileprivate(set) var description: String
  public fileprivate(set) var firebase: Firebase?
  public fileprivate(set) var hasReplay: Bool
  public fileprivate(set) var hlsUrl: String?
  public fileprivate(set) var id: Int
  public fileprivate(set) var isRtmp: Bool?
  public fileprivate(set) var isScale: Bool?
  public fileprivate(set) var liveNow: Bool
  public fileprivate(set) var maxOpenTokViewers: Int?
  public fileprivate(set) var name: String
  public fileprivate(set) var openTok: OpenTok?
  public fileprivate(set) var project: Project
  public fileprivate(set) var replayUrl: String?
  public fileprivate(set) var startDate: Date
  public fileprivate(set) var user: User?
  public fileprivate(set) var webUrl: String

  public struct Creator {
    public fileprivate(set) var avatar: String
    public fileprivate(set) var name: String
  }

  public struct Firebase {
    public fileprivate(set) var apiKey: String
    public fileprivate(set) var chatPath: String
    public fileprivate(set) var greenRoomPath: String
    public fileprivate(set) var hlsUrlPath: String
    public fileprivate(set) var numberPeopleWatchingPath: String
    public fileprivate(set) var project: String
    public fileprivate(set) var scaleNumberPeopleWatchingPath: String
  }

  public struct OpenTok {
    public fileprivate(set) var appId: String
    public fileprivate(set) var sessionId: String
    public fileprivate(set) var token: String
  }

  public struct Project {
    public fileprivate(set) var id: Int?
    public fileprivate(set) var name: String
    public fileprivate(set) var webUrl: String
  }

  public struct User {
    public fileprivate(set) var isSubscribed: Bool
  }

  // Useful for safeguarding against getting a `hasReplay == true` yet the `replayUrl` is `nil`.
  public var definitelyHasReplay: Bool {
    return self.hasReplay && self.replayUrl != nil
  }
}

public func == (lhs: LiveStreamEvent, rhs: LiveStreamEvent) -> Bool {
  return lhs.id == rhs.id
}

extension LiveStreamEvent: Decodable {
  static public func decode(_ json: JSON) -> Decoded<LiveStreamEvent> {
    return decodeLiveStreamV1(json)
  }
}

private func decodeLiveStreamV1(_ json: JSON) -> Decoded<LiveStreamEvent> {
  let create = curry(LiveStreamEvent.init)

  // Sometimes the project data is included in a `stream` sub-key, and sometimes it's in a `project` sub-key.
  let project: Decoded<LiveStreamEvent.Project> = (json <| "stream") <|> (json <| "project")

  let tmp1 = create
    <^> (json <| ["stream", "background_image_url"] <|> json <| "background_image_url")
    <*> json <| "creator"
    <*> (json <| ["stream", "description"] <|> json <| "description")
    <*> json <|? "firebase"
  let tmp2 = tmp1
    <*> (json <| ["stream", "has_replay"] <|> json <| "has_replay")
    <*> json <|? ["stream", "hls_url"]
    <*> json <| "id"
    <*> json <|? ["stream", "is_rtmp"]
  let tmp3 = tmp2
    <*> json <|? ["stream", "is_scale"]
    <*> (json <| ["stream", "live_now"] <|> json <| "live_now")
    <*> json <|? ["stream", "max_opentok_viewers"]
    <*> (json <| ["stream", "name"] <|> json <| "name")
  let tmp4 = tmp3
    <*> json <|? "opentok"
    <*> project
    <*> json <|? ["stream", "replay_url"]
    <*> ((json <| "start_date" <|> json <| ["stream", "start_date"]) >>- toDate)
  return tmp4
    <*> json <|? "user"
    <*> (json <| ["stream", "web_url"] <|> json <| "web_url")
}

extension LiveStreamEvent.Creator: Decodable {
  static public func decode(_ json: JSON) -> Decoded<LiveStreamEvent.Creator> {
    return curry(LiveStreamEvent.Creator.init)
      <^> json <| "creator_avatar"
      <*> json <| "creator_name"
  }
}

extension LiveStreamEvent.Firebase: Decodable {
  static public func decode(_ json: JSON) -> Decoded<LiveStreamEvent.Firebase> {
    let create = curry(LiveStreamEvent.Firebase.init)
    let tmp = create
      <^> json <| "firebase_api_key"
      <*> json <| "chat_path"
      <*> json <| "green_room_path"
    return tmp
      <*> json <| "hls_url_path"
      <*> json <| "number_people_watching_path"
      <*> json <| "firebase_project"
      <*> json <| "scale_number_people_watching_path"
  }
}

extension LiveStreamEvent.OpenTok: Decodable {
  static public func decode(_ json: JSON) -> Decoded<LiveStreamEvent.OpenTok> {
    return curry(LiveStreamEvent.OpenTok.init)
      <^> json <| "app"
      <*> json <| "session"
      <*> json <| "token"
  }
}

extension LiveStreamEvent.Project: Decodable {
  static public func decode(_ json: JSON) -> Decoded<LiveStreamEvent.Project> {

    // Sometimes the project id doesn't come back, and sometimes it comes back as `uid` even though it should
    // probably just be `id`, so want to protect against that.
    let id: Decoded<Int?> = (json <| "uid").map(Optional.some)
      <|> (json <| "id").map(Optional.some)
      <|> .success(nil)

    return curry(LiveStreamEvent.Project.init)
      <^> id
      <*> (json <| "project_name" <|> json <| "name")
      <*> (json <| "project_web_url" <|> json <| "web_url")
  }
}

extension LiveStreamEvent.User: Decodable {
  static public func decode(_ json: JSON) -> Decoded<LiveStreamEvent.User> {
    return curry(LiveStreamEvent.User.init)
      <^> json <| "is_subscribed"
  }
}

private let dateFormatter: DateFormatter = {
  let dateFormatter = DateFormatter()
  dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
  return dateFormatter
}()

private func toDate(dateString: String) -> Decoded<Date> {

  guard let date = dateFormatter.date(from: dateString) else {
    return .failure(DecodeError.custom("Unable to parse date format"))
  }

  return .success(date)
}

extension LiveStreamEvent {
  public enum lens {
    public static let hasReplay = Lens<LiveStreamEvent, Bool>(
      view: { $0.hasReplay },
      set: { var new = $1; new.hasReplay = $0; return new }
    )
    public static let hlsUrl = Lens<LiveStreamEvent, String?>(
      view: { $0.hlsUrl },
      set: { var new = $1; new.hlsUrl = $0; return new }
    )
    public static let id = Lens<LiveStreamEvent, Int>(
      view: { $0.id },
      set: { var new = $1; new.id = $0; return new }
    )
    public static let isRtmp = Lens<LiveStreamEvent, Bool?>(
      view: { $0.isRtmp },
      set: { var new = $1; new.isRtmp = $0; return new }
    )
    public static let isScale = Lens<LiveStreamEvent, Bool?>(
      view: { $0.isScale },
      set: { var new = $1; new.isScale = $0; return new }
    )
    public static let liveNow = Lens<LiveStreamEvent, Bool>(
      view: { $0.liveNow },
      set: { var new = $1; new.liveNow = $0; return new }
    )
    public static let maxOpenTokViewers = Lens<LiveStreamEvent, Int?>(
      view: { $0.maxOpenTokViewers },
      set: { var new = $1; new.maxOpenTokViewers = $0; return new }
    )
    public static let replayUrl = Lens<LiveStreamEvent, String?>(
      view: { $0.replayUrl },
      set: { var new = $1; new.replayUrl = $0; return new }
    )
    public static let startDate = Lens<LiveStreamEvent, Date>(
      view: { $0.startDate },
      set: { var new = $1; new.startDate = $0; return new }
    )
  }
}

extension LiveStreamEvent.Project {
  public enum lens {
    public static let id = Lens<LiveStreamEvent.Project, Int?>(
      view: { $0.id },
      set: { var new = $1; new.id = $0; return new }
    )

    public static let name = Lens<LiveStreamEvent.Project, String>(
      view: { $0.name },
      set: { var new = $1; new.name = $0; return new }
    )

    public static let webUrl = Lens<LiveStreamEvent.Project, String>(
      view: { $0.webUrl },
      set: { var new = $1; new.webUrl = $0; return new }
    )
  }
}
