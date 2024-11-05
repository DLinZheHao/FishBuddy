//
//  UIControlPublisher.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2024/11/5.
//

import UIKit
import Combine

/// A custom `Publisher` for `UIControl` to work with our custom `UIControlSubscription`.
struct UIControlPublisher<Control: UIControl>: Publisher {
    typealias Output = Control
    typealias Failure = Never

    let control: Control
    let controlEvents: UIControl.Event

    init(control: Control, events: UIControl.Event) {
        self.control = control
        self.controlEvents = events
    }

    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Failure, S.Input == Output {
        let subscription = UIControlSubscription(subscriber: subscriber, control: control, event: controlEvents)
        subscriber.receive(subscription: subscription)
    }
}

/// A custom subscription to capture UIControl target events.
final class UIControlSubscription<SubscriberType: Subscriber, Control: UIControl>: Subscription where SubscriberType.Input == Control {
    private var subscriber: SubscriberType?
    private let control: Control
    private let controlEvents: UIControl.Event

    init(subscriber: SubscriberType, control: Control, event: UIControl.Event) {
        self.subscriber = subscriber
        self.control = control
        self.controlEvents = event
        control.addTarget(self, action: #selector(eventHandler), for: event)
    }

    func request(_ demand: Subscribers.Demand) {
        // We do nothing here as we only want to send events when they occur.
        // See, for more info: https://developer.apple.com/documentation/combine/subscribers/demand
    }

    func cancel() {
        subscriber = nil
    }

    @objc private func eventHandler() {
        _ = subscriber?.receive(control)
    }
}

// Extend UIControl to provide a Combine compatible publisher.
protocol CombineCompatible { }

extension UIButton {
    // 擴展 UIButton 以支持 UIControl.Event 的 Combine 發布者
    func buttonPublisher(for events: UIControl.Event) -> UIControlPublisher<UIButton> {
        return UIControlPublisher(control: self, events: events)
    }
}


extension UITextField {
    // 擴展 UITextField 以支持 UIControl.Event 的 Combine 發布者
    func textFieldPublisher(for events: UIControl.Event) -> UIControlPublisher<UITextField> {
        return UIControlPublisher(control: self, events: events)
    }
    
    // 擴展 UITextField 以添加對 textFieldShouldClear 的支持
    // Publisher for textFieldShouldClear event
    func textFieldShouldClearPublisher() -> AnyPublisher<UITextField, Never> {
        let publisher = PassthroughSubject<UITextField, Never>()
                
        // Implement the textFieldShouldClear delegate method
        func textFieldShouldClear(_ textField: UITextField) -> Bool {
            publisher.send(textField)
            return true // or false, depending on your logic
        }
        return publisher.eraseToAnyPublisher()
    }
}

extension UISegmentedControl {
    func segmentedPublisher(for events: UIControl.Event) -> UIControlPublisher<UISegmentedControl> {
        return UIControlPublisher(control: self, events: events)
    }
}

