//
//  ViewController.swift
//  RallyExample
//
//  Created by Bartosz Polaczyk on 23/05/2017.
//  Copyright © 2017 Railwaymen. All rights reserved.
//

import UIKit
import Rally
import ExternalAccessory
import CocoaLumberjack

class ViewController: UIViewController {
    
    private var battery:RALBatteryController = RALBatteryController.shared();
    @IBOutlet weak var messageLabel: UILabel!
    
   
    override func viewWillAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: RALBatteryConnectedNotification), object: nil, queue: nil, using: hardwareConnected);
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: RALBatteryDisconnectedNotification), object: nil, queue: nil, using: hardwareDisconnected);
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Rally events handlers
    
    private func hardwareConnected (notification: Notification){
        guard let accessory = self.battery.currentAccessory else{
            return
        }
        
        logInfo("Hardware connected: \(accessory)")
        showAlert(withBody:"Connected hardware: \(accessory.name)")
        showMessage("Charger Connected")
    }
    
    private func hardwareDisconnected (notification: Notification){
        logInfo("Hardware disconnected")
        showAlert(withBody:"Disconnected hardware")
        showMessage("")
    }
    
    // MARK: - UI presentation
    
    private func showAlert(withBody body:String){
        DispatchQueue.main.async {
            let alertVC = UIAlertController(title: "Rally event", message: body, preferredStyle: .alert)
            alertVC.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.show(alertVC, sender: nil)
        }
    }
    
    private func showMessage(_ message:String){
        DispatchQueue.main.async {
            self.messageLabel.text = message
        }
    }
    
    //MARK: - Actions
    
    
    @IBAction func chargeAction(_ sender: Any) {
        guard battery.connected else {
            showAlert(withBody: "No charger connected")
            return
        }
        logInfo("Sending start charing")
        battery.startCharging()
    }
    
    @IBAction func stopAction(_ sender: Any) {
        guard battery.connected else {
            showAlert(withBody: "No charger connected")
            return
        }
        
        logInfo("Sending stop charing")
        battery.stopCharging()
    }
    
    
    
}

