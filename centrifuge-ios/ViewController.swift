//
//  ViewController.swift
//  centrifuge-ios
//
//  Created by Muhammad Fahad on 14/07/2021.
//

import UIKit
import SwiftCentrifuge

class ViewController: UIViewController{
    
    @IBOutlet weak var labelMessage: UILabel!
    
    private var client: CentrifugeClient?
    private var sub: CentrifugeSubscription?
    private var isConnected: Bool = false
    private var subscriptionCreated: Bool = false
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let config = CentrifugeClientConfig()
        self.client = CentrifugeClient(url: CENTRIFUGAL_HOST, config: config, delegate: self)
        self.client?.setToken(JWT_TOKEN)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.isConnected {
            self.client?.disconnect()
        } else {
            self.client?.connect()
            if !self.subscriptionCreated {
                // Only subscribe once, after this client will internally keep all subscriptions
                // so we don't need to subscribe again.
                self.createSubscription()
                self.subscriptionCreated = true
            }
        }
    }
    
    
    private func createSubscription() {
        do {
            sub = try self.client?.newSubscription(channel: CHAT, delegate: self)
        } catch {
            print("Can not create subscription: \(error)")
            return
        }
        sub?.subscribe()
    }
}

extension ViewController: CentrifugeClientDelegate {
    func onConnect(_ c: CentrifugeClient, _ e: CentrifugeConnectEvent) {
        self.isConnected = true
        print("connected with id", e.client)
    }
    
    func onDisconnect(_ c: CentrifugeClient, _ e: CentrifugeDisconnectEvent) {
        self.isConnected = false
        print("disconnected", e.reason, "reconnect", e.reconnect)
        
    }
    
    func onSubscribe(_ client: CentrifugeClient, _ event: CentrifugeServerSubscribeEvent) {
        print("server-side subscribe to", event.channel, "recovered", event.recovered, "resubscribe", event.resubscribe)
    }
    
    func onPublish(_ client: CentrifugeClient, _ event: CentrifugeServerPublishEvent) {
        print("server-side publication from", event.channel, "offset", event.offset)
    }
    
    func onUnsubscribe(_ client: CentrifugeClient, _ event: CentrifugeServerUnsubscribeEvent) {
        print("server-side unsubscribe from", event.channel)
    }
    
    func onJoin(_ client: CentrifugeClient, _ event: CentrifugeServerJoinEvent) {
        print("server-side join in", event.channel, "client", event.client)
    }
    
    func onLeave(_ client: CentrifugeClient, _ event: CentrifugeServerLeaveEvent) {
        print("server-side leave in", event.channel, "client", event.client)
    }
}

extension ViewController: CentrifugeSubscriptionDelegate {
    func onPublish(_ s: CentrifugeSubscription, _ e: CentrifugePublishEvent) {
        let data = String(data: e.data, encoding: .utf8) ?? ""
        print("message from channel", s.channel, data)
        DispatchQueue.main.async { [weak self] in
            self?.labelMessage.text = data.toDictionary()?["message"] as? String ?? "N/A"
        }
    }
    
    func onSubscribeSuccess(_ s: CentrifugeSubscription, _ e: CentrifugeSubscribeSuccessEvent) {
        s.presence(completion: { result, error in
            if let err = error {
                print("Unexpected presence error: \(err)")
            } else if let presence = result {
                print(presence)
            }
        })
        print("successfully subscribed to channel \(s.channel)")
    }
    
    func onSubscribeError(_ s: CentrifugeSubscription, _ e: CentrifugeSubscribeErrorEvent) {
        print("failed to subscribe to channel", e.code, e.message)
    }
    
    func onUnsubscribe(_ s: CentrifugeSubscription, _ e: CentrifugeUnsubscribeEvent) {
        print("unsubscribed from channel", s.channel)
    }
    
    func onJoin(_ s: CentrifugeSubscription, _ e: CentrifugeJoinEvent) {
        print("client joined channel \(s.channel), user ID \(e.user)")
    }
    
    func onLeave(_ s: CentrifugeSubscription, _ e: CentrifugeLeaveEvent) {
        print("client left channel \(s.channel), user ID \(e.user)")
    }
}


extension String {
    
    func toDictionary() -> [String:Any]? {
        if let data = self.data(using: .utf8){
            do {
                return try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as? [String: Any]
            } catch let error {
                print(error)
                return nil
            }
        }
        return nil
    }
}
