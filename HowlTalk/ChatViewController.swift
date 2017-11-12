//
//  ChatViewController.swift
//  HowlTalk
//
//  Created by 유명식 on 2017. 9. 26..
//  Copyright © 2017년 swift. All rights reserved.
//

import UIKit
import Firebase

class ChatViewController: UIViewController,UITableViewDelegate,UITableViewDataSource {
    
    
    @IBOutlet weak var bottomContraint: NSLayoutConstraint!
    
    @IBOutlet weak var tableview: UITableView!
    
    
    @IBOutlet weak var textfield_message: UITextField!
    
    @IBOutlet weak var sendButton: UIButton!
    
    var uid : String?
    var chatRoomUid : String?
    
    var comments : [ChatModel.Comment] = []
    var userModel :UserModel?
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        uid = Auth.auth().currentUser?.uid
        sendButton.addTarget(self, action: #selector(createRoom), for: .touchUpInside)
        checkChatRoom()
        self.tabBarController?.tabBar.isHidden = true
        
        let tap :UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
        // Do any additional setup after loading the view.
    }
    
    
    //시작
    
    override func viewWillAppear(_ animated: Bool) {
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: .UIKeyboardWillHide, object: nil)
    }
    
    
    //종료
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
        self.tabBarController?.tabBar.isHidden = false
    }
    
    
    func keyboardWillShow(notification : Notification){
        
        if let keyboardSize = (notification.userInfo![UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue{
            
            self.bottomContraint.constant = keyboardSize.height
        }
        
        UIView.animate(withDuration: 0, animations: {
            self.view.layoutIfNeeded()
        }, completion: {
            (complete) in
            
            if self.comments.count > 0{
                self.tableview.scrollToRow(at: IndexPath(item:self.comments.count - 1,section:0), at: UITableViewScrollPosition.bottom, animated: true)
            
            }
            
            
        })
    }
    func keyboardWillHide(notification:Notification){
        
        self.bottomContraint.constant = 20
        self.view.layoutIfNeeded()
        
    }
    
    func dismissKeyboard(){
        
        self.view.endEditing(true)
    }
    
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return comments.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if(self.comments[indexPath.row].uid == uid){
            let view = tableView.dequeueReusableCell(withIdentifier: "MyMessageCell", for: indexPath) as! MyMessageCell
            view.label_message.text = self.comments[indexPath.row].message
            view.label_message.numberOfLines = 0
            
            if let time = self.comments[indexPath.row].timestamp{
                view.label_timestamp.text = time.toDayTime
            }
            
            
            
            
            return view
            
        }else{
            
            let view = tableView.dequeueReusableCell(withIdentifier: "DestinationMessageCell", for: indexPath) as! DestinationMessageCell
            view.label_name.text = userModel?.userName
            view.label_message.text = self.comments[indexPath.row].message
            view.label_message.numberOfLines = 0;
            
            let url = URL(string:(self.userModel?.profileImageUrl)!)
            URLSession.shared.dataTask(with: url!, completionHandler: { (data, response, err) in
                
                DispatchQueue.main.async {
                    
                    view.imageview_profile.image = UIImage(data: data!)
                    view.imageview_profile.layer.cornerRadius = view.imageview_profile.frame.width/2
                    view.imageview_profile.clipsToBounds = true
                    
                }
            }).resume()
            if let time = self.comments[indexPath.row].timestamp{
                view.label_timestamp.text = time.toDayTime
            }
            
            
            
            return view
            
        }
        
        
        
        
        
        return UITableViewCell()
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    
    
    
    public var destinationUid :String? // 나중에 내가 채팅할 대상의 uid
   

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func createRoom(){
        let createRoomInfo : Dictionary<String,Any> = [ "users" : [
            uid!: true,
            destinationUid! :true
            ]
        ]
        
        
        if(chatRoomUid == nil){
            self.sendButton.isEnabled = false
            // 방 생성 코드
            Database.database().reference().child("chatrooms").childByAutoId().setValue(createRoomInfo, withCompletionBlock: { (err, ref) in
                if(err == nil){
                    self.checkChatRoom()
                }
            })
            
        }else{
            let value :Dictionary<String,Any> = [

                    "uid" : uid!,
                    "message" : textfield_message.text!,
                    "timestamp" : ServerValue.timestamp()
            ]
            
            Database.database().reference().child("chatrooms").child(chatRoomUid!).child("comments").childByAutoId().setValue(value, withCompletionBlock: { (err, ref) in
                self.textfield_message.text = ""
            })
        }
        
        
        
        
        
    }
    func checkChatRoom(){
        
        Database.database().reference().child("chatrooms").queryOrdered(byChild: "users/"+uid!).queryEqual(toValue: true).observeSingleEvent(of: DataEventType.value,with: { (datasnapshot) in
            for item in datasnapshot.children.allObjects as! [DataSnapshot]{
                
                if let chatRoomdic = item.value as? [String:AnyObject]{
                    
                    let chatModel = ChatModel(JSON: chatRoomdic)
                    if(chatModel?.users[self.destinationUid!] == true){
                            self.chatRoomUid = item.key
                        self.sendButton.isEnabled = true
                        self.getDestinationInfo()
                    }
                }
                
               
                
            }
        })
        
    }
    
    func getDestinationInfo(){
        
        Database.database().reference().child("users").child(self.destinationUid!).observeSingleEvent(of: DataEventType.value, with: { (datasnapshot) in
            self.userModel = UserModel()
            self.userModel?.setValuesForKeys(datasnapshot.value as! [String:Any])
            self.getMessageList()
            
        })
    }
    func getMessageList(){
        
        Database.database().reference().child("chatrooms").child(self.chatRoomUid!).child("comments").observe(DataEventType.value, with: { (datasnapshot) in
            self.comments.removeAll()
            
            for item in datasnapshot.children.allObjects as! [DataSnapshot]{
                let comment = ChatModel.Comment(JSON: item.value as! [String:AnyObject])
                self.comments.append(comment!)
            }
            self.tableview.reloadData()
            
            if self.comments.count > 0{
                self.tableview.scrollToRow(at: IndexPath(item:self.comments.count - 1,section:0), at: UITableViewScrollPosition.bottom, animated: true)
                
            }
            
            
            
        })
        
    }
    
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

extension Int{
    
    var toDayTime :String{
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ko_KR")
        dateFormatter.dateFormat = "yyyy.MM.dd HH:mm"
        let date = Date(timeIntervalSince1970: Double(self)/1000)
        return dateFormatter.string(from: date)
        
    }
    
}
class MyMessageCell :UITableViewCell{
    
    @IBOutlet weak var label_message: UILabel!
    
    @IBOutlet weak var label_timestamp: UILabel!
}

class DestinationMessageCell :UITableViewCell{
    @IBOutlet weak var label_message: UILabel!
    @IBOutlet weak var imageview_profile: UIImageView!
    
    @IBOutlet weak var label_timestamp: UILabel!
    @IBOutlet weak var label_name: UILabel!
}
