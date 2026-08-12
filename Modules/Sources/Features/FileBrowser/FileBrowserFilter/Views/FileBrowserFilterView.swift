import SwiftUI
import Core
import Localization

// MARK: - FileBrowserFilterView

/// フィルターボタンからハーフモーダルで表示するフィルター設定画面。
/// ナビゲーションバーは持たず、コンテンツの理想サイズに合わせて高さが決まるボトムシートとして表示される
/// （高さの決定はFileBrowserFilterViewController / FileBrowserViewController側が担う）。
/// 星・カラーラベルのアイコン表現はPhotoViewerの`RatingLabelBarView`（既存UIView）に合わせている。
/// viewModelのratingFilter/colorLabelFilterへ直接反映し、変更はonChange経由でFileBrowserViewModelへ通知される。
public struct FileBrowserFilterView: View {

    // FileBrowserFilterViewControllerから渡された値をこのViewが保持する。
    // 参照型（@Observable）なので@Stateで保持してもプロパティの変更はそのままonChangeへ伝播する。
    @State private var viewModel: FileBrowserFilterViewModel

    init(viewModel: FileBrowserFilterViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionContainer(title: L10n.FileBrowser.ratingFilterStars) {
                ratingRow
            }
            sectionContainer(title: L10n.FileBrowser.colorLabel) {
                colorLabelRow
            }

            clearFilterButton
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ignoresSafeArea()
    }

    // MARK: - セクション

    private func sectionContainer(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 星評価＋条件

    private var currentStars: Int { viewModel.ratingFilter?.stars ?? 0 }
    private var currentComparison: RatingFilter.Comparison { viewModel.ratingFilter?.comparison ?? .atLeast }

    /// 星1〜5の隣に比較条件（≧・≦・=）を並べる。RatingLabelBarViewの「スター列＋区切り線＋アイコン列」の構成を踏襲する
    private var ratingRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { position in
                    starButton(position)
                }
            }
            .padding(.horizontal, 8)
            .background(Capsule().fill(Color(.systemGray5).opacity(0.6)))

            pillSeparator
            comparisonPicker
        }
    }

    private func starButton(_ position: Int) -> some View {
        let isFilled = position <= currentStars
        return Button {
            let newStars = currentStars == position ? 0 : position
            viewModel.ratingFilter = RatingFilter(stars: newStars, comparison: currentComparison)
        } label: {
            // 選択中はラベルの前景色（ライトテーマ黒・ダークテーマ白）で塗りつぶす
            Image(systemName: isFilled ? "star.fill" : "star")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isFilled ? Color.primary : Color.secondary)
                .frame(width: 36, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.FileBrowser.ratingFilterStarValue(position))
    }

    private var comparisonPicker: some View {
        Picker(L10n.FileBrowser.ratingFilterComparison, selection: comparisonBinding) {
            Text("≧").tag(RatingFilter.Comparison.atLeast)
            Text("≦").tag(RatingFilter.Comparison.atMost)
            Text("=").tag(RatingFilter.Comparison.exactly)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var comparisonBinding: Binding<RatingFilter.Comparison> {
        Binding(
            get: { currentComparison },
            set: { newValue in
                viewModel.ratingFilter = RatingFilter(stars: currentStars, comparison: newValue)
            }
        )
    }

    private var pillSeparator: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.3))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 2)
    }

    // MARK: - カラーラベル

    /// 6色を横並びし、タップで複数選択のON/OFFを切り替える。
    /// アイコンはRatingLabelBarViewと同じ組み合わせ（未選択circle.fill／選択中circle.inset.filled、
    /// どちらもラベル自身の色でtint）にして見た目を揃える。
    private var colorLabelRow: some View {
        HStack(spacing: 4) {
            ForEach(PhotoColorLabel.allCases, id: \.self) { label in
                colorLabelButton(for: label)
            }
        }
        .padding(.horizontal, 8)
        .background(Capsule().fill(Color(.systemGray5).opacity(0.6)))
    }

    private func colorLabelButton(for label: PhotoColorLabel) -> some View {
        let isSelected = viewModel.colorLabelFilter.contains(label)
        return Button {
            var selection = viewModel.colorLabelFilter
            if selection.contains(label) {
                selection.remove(label)
            } else {
                selection.insert(label)
            }
            viewModel.colorLabelFilter = selection
        } label: {
            Image(systemName: isSelected ? "circle.inset.filled" : "circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color(uiColor: label.uiColor))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.ColorLabel.name(forRawValue: label.rawValue))
    }

    // MARK: - フィルタークリア

    private var clearFilterButton: some View {
        Button(role: .destructive) {
            viewModel.clearFilters()
        } label: {
            Text(L10n.FileBrowser.ratingFilterOff)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }
}
