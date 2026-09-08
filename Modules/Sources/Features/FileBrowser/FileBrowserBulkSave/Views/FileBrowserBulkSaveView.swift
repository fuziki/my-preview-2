import SwiftUI
import Localization

// MARK: - FileBrowserBulkSaveView

/// 「全て保存」の進捗を表示するオーバーレイ。半透明の黒背景の上に進捗と中断ボタンを乗せたカードを中央配置する。
/// 裏のFileBrowserViewControllerが薄暗く透けて見える見た目にする（グレーアウト）。
/// 表示と同時にviewModel.start()を開始し、完了・中断・失敗のいずれかでonFinished経由に画面が閉じられる
/// （画面を閉じる操作自体はFileBrowserBulkSaveViewControllerが担う）。
public struct FileBrowserBulkSaveView: View {

    // FileBrowserBulkSaveViewControllerから渡された値をこのViewが保持する。
    // 参照型（@Observable）なので@Stateで保持してもプロパティの変更はそのまま画面に反映される。
    @State private var viewModel: FileBrowserBulkSaveViewModel

    init(viewModel: FileBrowserBulkSaveViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text(L10n.FileBrowser.bulkSaveTitle)
                    .font(.headline)
                    .foregroundStyle(.white)

                ProgressView(value: Double(viewModel.completedCount), total: Double(max(viewModel.totalCount, 1)))
                    .progressViewStyle(.linear)
                    .tint(.white)
                    .frame(width: 220)

                Text(L10n.FileBrowser.bulkSaveProgress(viewModel.completedCount, viewModel.totalCount))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))

                Button {
                    viewModel.cancel()
                } label: {
                    Text(L10n.FileBrowser.bulkSaveCancel)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
            .padding(24)
            .frame(width: 260)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
        .task {
            await viewModel.start()
        }
    }
}
