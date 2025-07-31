// ViewController.swift
import UIKit

class ViewController: UIViewController {
    private let logView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        return textView
    }()

    private let resultLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "Running XPC PoC..."
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(logView)
        NSLayoutConstraint.activate([
            logView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            logView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            logView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            logView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5)
        ])
        view.addSubview(resultLabel)
        NSLayoutConstraint.activate([
            resultLabel.topAnchor.constraint(equalTo: logView.bottomAnchor, constant: 20),
            resultLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            resultLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            resultLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        DispatchQueue.global(qos: .userInitiated).async {
            let result = String(cString: run_xpc_poc())
            DispatchQueue.main.async {
                self.logView.text = "PoC Log:\n\(result)"
                self.resultLabel.text = result.contains("Failed") ? "PoC Failed" : "PoC Succeeded"
            }
        }
    }
}
