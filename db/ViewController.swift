import UIKit
import SnapKit
import FirebaseDatabase
import FirebaseAnalytics

class ViewController: UIViewController {
    lazy var ref = Database.database().reference()
    let tableView = UITableView(frame: .zero, style: .insetGrouped)
    var items: [String] = []
    var keys: [String] = []
    var noteKey: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        makeConstaints()
        observe()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        noteKey = nil
    }
}

private extension ViewController {
    func observe() {
        ref.child("items").observe(.value) { snapshot in
            if let items = snapshot.value as? [String: String] {
                self.items = items.map { $0.value }
                self.keys = items.map { $0.key }
                self.tableView.reloadData()
            }
        }
    }
    
    func setupView() {
        title = "Главная"
        view.backgroundColor = .systemBackground
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .add)
        navigationItem.rightBarButtonItem?.primaryAction = UIAction { _ in
            self.addItem()
        }
    }
    
    func addItem() {
        let vc = SecondViewController()
        vc.delegate = self
        vc.noteKey = noteKey
        self.navigationController?.pushViewController(vc, animated: true)
        Analytics.logEvent("AddItemButtonTapped", parameters: nil)
    }
    
    func makeConstaints() {
        tableView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = items[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        let key = keys[indexPath.row]
        ref.child("items").child(key).removeValue()
        Analytics.logEvent("deleted", parameters: nil)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let text = items[indexPath.row]
        let key = keys[indexPath.row]
        let vc = SecondViewController(text: text, noteKey: key)
        vc.delegate = self
        noteKey = key
        navigationController?.pushViewController(vc, animated: true)
        Analytics.logEvent("noteTapped", parameters: nil)
    }
}

class SecondViewController: UIViewController {
    var noteKey: String?
    
    convenience init(text: String, noteKey: String) {
        self.init()
        utv.text = text
        self.noteKey = noteKey
    }
    
    let utv: UITextView = {
        let utv = UITextView()
        utv.text = ""
        utv.font = UIFont(name: "Verdana", size: 16)
        utv.becomeFirstResponder()
        return utv
    }()
    
    var delegate: UITextViewDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUtv()
        
        if utv.text == "" {
            title = "Новая заметка"
        } else {
            title = utv.text
        }
    }
    
    func setupUtv() {
        view.addSubview(utv)
        utv.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.width.equalToSuperview().multipliedBy(0.8)
            $0.height.equalTo(200)
        }
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))
        navigationItem.rightBarButtonItem = doneButton
    }
    @objc func doneButtonTapped() {
        delegate?.textViewDidChange?(utv)
        navigationController?.popViewController(animated: true)
    }
}
extension ViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        if let key = noteKey {
            let newValue = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if newValue.isEmpty {
                ref.child("items").child(key).removeValue()
            } else {
                ref.child("items").child(key).setValue(newValue)
                Analytics.logEvent("Edited", parameters: nil)
            }
        } else {
            let key = ref.child("items").childByAutoId().key
            let newValue = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newValue.isEmpty {
                ref.child("items").child(key ?? "").setValue(newValue)
                Analytics.logEvent("newNoteAdded", parameters: ["value": newValue])
            }
        }
    }
}

