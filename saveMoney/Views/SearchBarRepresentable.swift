import SwiftUI
import UIKit

// 기존 storyboard의 UISearchBar 디자인을 SwiftUI에서 그대로 쓰기 위한 래퍼.
// (.searchTextField.font 14 semibold, 투명 배경, 검색 아이콘 숨김 — 원본 searchVC와 동일 셋업)
struct SearchBarRepresentable: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var becomeFirstResponderOnAppear: Bool = false

    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar()
        searchBar.delegate = context.coordinator
        searchBar.placeholder = placeholder
        searchBar.searchTextField.font = .systemFont(ofSize: 14, weight: .semibold)
        searchBar.searchTextField.backgroundColor = .clear
        searchBar.setImage(UIImage(), for: .search, state: .normal)
        searchBar.backgroundImage = UIImage()
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        // 키보드 등장을 push 전환 애니메이션(~0.35s) 이후로 지연.
        // 즉시 becomeFirstResponder()하면 push 슬라이드와 키보드 등장이 겹쳐 버벅임.
        if becomeFirstResponderOnAppear, !context.coordinator.didFocus {
            context.coordinator.didFocus = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak searchBar] in
                searchBar?.becomeFirstResponder()
            }
        }
        return searchBar
    }

    func updateUIView(_ uiView: UISearchBar, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, UISearchBarDelegate {
        @Binding var text: String
        var didFocus: Bool = false

        init(text: Binding<String>) {
            self._text = text
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.endEditing(true)
        }
    }
}
