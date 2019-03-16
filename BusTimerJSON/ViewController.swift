//  ViewController.swift
//  BusTimerJSON
//
//  Created by Leonard Choo on 2018/10/27.
//  Copyright © 2018 team-sfcbustimer. All rights reserved.
//
import UIKit
import SwiftyJSON

// global variables
var currUserTime = Date()
var nextBusTime: Date? = nil
var userDirection = "sfcsho"
var dept = "sfc"
var arrv = "Shonandai"
var timetableJson = JSON()
var holidaysJson = JSON()
var upcomingBuses: [JSON] = []

extension TimeInterval {
    func stringFromTimeInterval() -> String {
        let time = Int(self)
        let seconds = time % 60
        let minutes = (time / 60) % 60
        let hours = (time / 3600)
        return String(format: "%0.2d:%0.2d:%0.2d",hours,minutes,seconds)
    }
}


class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var departure: UILabel!
    @IBOutlet weak var arrival: UILabel!
    @IBOutlet weak var timeLeft: UILabel!
    @IBOutlet weak var changeDirection: UIButton!
    @IBOutlet weak var busInfo: UILabel!
    @IBOutlet var changeLocation: UIButton!
    @IBOutlet weak var tableView: UITableView!
    
    
    var timer = Timer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //UserDefaultsのデータをjson化
        timetableJson = DataUtils.parseTimetableJson()
        holidaysJson = DataUtils.parseHolidaysJson()
        
        //TO DO
        //ローカルデータがない場合の処理
        
        // Run main() and wait for it to finish
        let group = DispatchGroup()
        
        group.enter()
        main()
        group.leave()
        
        // execute the timer only after
        group.notify(queue: .main){
            if self.timer.isValid{
                self.timer.invalidate()
                self.timer = Timer()
            }
            
            //            print("2 nextBusTime: \(nextBusTime)")
            //call every 1 sec
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                //                print("3 nextBusTime: \(nextBusTime)")
                self.updateTimeLeft(busTime: nextBusTime)
            }
        }
        
    }
    
    func main() {
        let nextBusDateObj = getNextBus()
        // no bus left
        if nextBusDateObj == nil{
            //                print("No BUS")
            DispatchQueue.main.async {//ui update always uses main thread
                self.busInfo.text = "No bus!"
            }
        } else {
            //show next bus
            DispatchQueue.main.async {
                self.busInfo.numberOfLines = 0
                self.busInfo.text = DateUtils.dateToStr(dateObj: nextBusDateObj)
                nextBusTime = nextBusDateObj
                self.tableView.reloadData()
                self.updateTimeLeft(busTime: nextBusTime)
            }
        }
    }
    
    func getNextBus() -> (Date?){
        // TO DO: change these to user inputs later
        // var userWeek = ""
        var _nextBus: Date? = nil
        upcomingBuses = [] //初期化
        
        //variables for searching in bus for loop
        var isNextBusFound = false
        var upcomingBusesCount = 0;
        
        currUserTime = Date()
        
        
        // Get correct userWeek data (weekend, sat, sun)
        let arrayKeys = Array(holidaysJson.dictionaryValue.keys)
        var todayFormatted = DateUtils.getDateTime()
        todayFormatted = todayFormatted.replacingOccurrences(of: "/", with: "-", options: .literal, range: nil)
        let userWeek = DateUtils.identifyDayType(today: todayFormatted, holidays: arrayKeys)
        
        
        // Get the next bus information
        let busSchedule = timetableJson[userDirection][userWeek].arrayValue
        print(type(of:busSchedule))
        let lastBus = busSchedule.last
        let lastBusObj = DateUtils.jsonToDateObj(jsonObj: lastBus)
        if lastBusObj! < currUserTime{
            print("Last bus has left!")
        }
        else{
            for bus in busSchedule{
                let busTimeObj = DateUtils.jsonToDateObj(jsonObj: bus)
                if busTimeObj! > currUserTime{
                    if(!isNextBusFound){
                        print("Found next bus at", DateUtils.dateToStr(dateObj: busTimeObj))
                        _nextBus = busTimeObj
                        isNextBusFound = true
                    }
                    upcomingBuses.append(bus)
                    upcomingBusesCount += 1
                    if(upcomingBusesCount > 4) {break}
                }
            }
        }
        return _nextBus
    }
    
    
    func updateTimeLeft(busTime: Date?) {
        if busTime == nil{
            self.timeLeft.text = "no more bus"
        }else{
            currUserTime = Date()
            //    print("current user time \(currUserTime)")
            //    print("busTime \(busTime)")
            //            print("4 nextBusTime: \(busTime)")
            let elapsedTime = busTime?.timeIntervalSince(currUserTime)
            if Double(elapsedTime ?? 0) > 0 {
                //print("elap: \(elapsedTime) double: \(Double(elapsedTime ?? 0)) int: \(Int(elapsedTime ?? 0))")
                self.timeLeft.text = elapsedTime?.stringFromTimeInterval()
            } else{
                main()
            }
        }
    }
    
    @IBAction func changeDirection(_ sender: Any) {
        
        let temp = self.departure.text
        self.departure.text = self.arrival.text
        self.arrival.text = temp
        
        if userDirection == "sfcsho" {
            userDirection = "shosfc"
            
        } else if userDirection == "shosfc"{
            userDirection = "sfcsho"
            
        } else if userDirection == "sfctsuji"{
            userDirection = "tsujisfc"
            
        } else if userDirection == "tsujisfc"{
            userDirection = "sfctsuji"
        }
        // re-calculate the next bus
        main()
        
    }
    
    @IBAction func changeLocation(_ sender: Any) {
        if self.departure.text == "Shonandai" {
            self.departure.text = "Tsujido"
            userDirection = "tsujisfc"
        }
        else if self.arrival.text == "Shonandai" {
            self.arrival.text = "Tsujido"
            userDirection = "sfctsuji"
        }
        else if self.departure.text == "Tsujido" {
            self.departure.text = "Shonandai"
            userDirection = "shosfc"
        }
        else if self.arrival.text == "Tsujido" {
            self.arrival.text = "Shonandai"
            userDirection = "sfcsho"
        }
        
        main()
    }
    
    @IBAction func checkData(_ sender: Any){
        DataUtils.checkData()
    }
    
    @IBAction func deleteData(_ sender: Any){
        DataUtils.DeleteData()
    }
    
    //table view関連セクション
    //セルの個数を指定するデリゲートメソッド
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 5
    }
    //セルに値を設定するデータソースメソッド
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // セルを取得する
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "upcomingBusesCell", for: indexPath)
        // indexPath.row番目のセルに表示する値を設定する
        cell.textLabel!.text = DateUtils.dateToStr(dateObj:
            DateUtils.jsonToDateObj(jsonObj: upcomingBuses[indexPath.row]))
        return cell
    }
}
