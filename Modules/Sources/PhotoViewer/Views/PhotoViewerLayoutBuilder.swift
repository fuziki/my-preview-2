import UIKit

/// PhotoViewerViewControllerのビュー階層構築・Auto Layout制約設定をまとめた名前空間。
/// PhotoViewerViewController側のプロパティは private のまま保つため、
/// ここでは必要なビュー・状態を引数として受け取り、結果を戻り値で返す形にしている。
enum PhotoViewerLayoutBuilder {

    /// setupOverlay(...)が生成する縦持ち/横持ちそれぞれの制約セット
    struct BottomBarConstraints {
        let portrait: [NSLayoutConstraint]
        let landscape: [NSLayoutConstraint]
    }

    /// 縦持ち/横持ちの制約セットを入れ替える
    static func toggleBottomBarLayout(
        toLandscape isLandscape: Bool,
        portraitConstraints: [NSLayoutConstraint],
        landscapeConstraints: [NSLayoutConstraint]
    ) {
        if isLandscape {
            NSLayoutConstraint.deactivate(portraitConstraints)
            NSLayoutConstraint.activate(landscapeConstraints)
        } else {
            NSLayoutConstraint.deactivate(landscapeConstraints)
            NSLayoutConstraint.activate(portraitConstraints)
        }
    }

    /// フォトビューアの各フローティングUI要素をcontainerViewへ追加し、Auto Layout制約を設定する。
    /// 縦持ち/横持ちで切り替える制約セット（レーティングバー・PiP/回転座布団・保存ボタン付近）は
    /// 戻り値として返し、呼び出し側で保持・activate/deactivateしてもらう。
    static func setupOverlay(
        containerView: UIView,
        closeButtonView: GlassButtonView,
        prevButtonView: GlassButtonView,
        nextButtonView: GlassButtonView,
        prevHitAreaButton: UIButton,
        nextHitAreaButton: UIButton,
        photoInfoPillView: PhotoInfoPillView,
        thumbnailImageView: UIImageView,
        saveButtonView: GlassButtonView,
        pipOrientationBarView: PiPOrientationBarView,
        ratingLabelBarView: RatingLabelBarView,
        bottomBarGroupGuide: UILayoutGuide,
        loadingIndicator: UIActivityIndicatorView,
        lastSavedDateLabel: UILabel,
        isRatingEnabled: Bool
    ) -> BottomBarConstraints {
        var portraitBottomBarConstraints: [NSLayoutConstraint] = []
        var landscapeBottomBarConstraints: [NSLayoutConstraint] = []

        // 各フローティング要素をcollectionViewの上に直接追加する。

        // 閉じるボタン: 左上のフローティング円
        containerView.addSubview(closeButtonView)
        NSLayoutConstraint.activate([
            closeButtonView.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButtonView.leadingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.leadingAnchor, constant: 16),
        ])

        // 前へボタン: 左下のフローティング円
        containerView.addSubview(prevButtonView)
        NSLayoutConstraint.activate([
            prevButtonView.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            prevButtonView.leadingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.leadingAnchor, constant: 16),
        ])

        // 次へボタン: 右下のフローティング円
        containerView.addSubview(nextButtonView)
        NSLayoutConstraint.activate([
            nextButtonView.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            nextButtonView.trailingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.trailingAnchor, constant: -16),
        ])

        // ファイル名 + EXIF: 右上のフローティングピル。コンテンツ幅に応じて自身も収縮するため、
        // leadingはcloseButtonViewと重ならないための床（下限）のみ（ファイル名は中略で1行表示）
        containerView.addSubview(photoInfoPillView)
        NSLayoutConstraint.activate([
            photoInfoPillView.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor, constant: 12),
            photoInfoPillView.leadingAnchor.constraint(greaterThanOrEqualTo: closeButtonView.trailingAnchor, constant: 8),
            photoInfoPillView.trailingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.trailingAnchor, constant: -16),
        ])

        // サムネイル: ファイル名ラベルの下、右揃え
        containerView.addSubview(thumbnailImageView)
        NSLayoutConstraint.activate([
            thumbnailImageView.topAnchor.constraint(equalTo: photoInfoPillView.bottomAnchor, constant: 8),
            thumbnailImageView.trailingAnchor.constraint(equalTo: photoInfoPillView.trailingAnchor),
        ])

        // 保存ボタン: 下部中央のカプセル形
        // centerXは縦持ち/横持ちで意味が変わる（横持ちはレーティングバーとの組を中央揃えするため）ため、
        // レーティング有効時はここでは固定せずportrait/landscapeの制約セット側で設定する。
        containerView.addSubview(saveButtonView)
        NSLayoutConstraint.activate([
            saveButtonView.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            saveButtonView.leadingAnchor.constraint(greaterThanOrEqualTo: prevButtonView.trailingAnchor, constant: 8),
            saveButtonView.trailingAnchor.constraint(lessThanOrEqualTo: nextButtonView.leadingAnchor, constant: -8),
            saveButtonView.heightAnchor.constraint(equalToConstant: 44),
            saveButtonView.button.topAnchor.constraint(equalTo: saveButtonView.topAnchor),
            saveButtonView.button.bottomAnchor.constraint(equalTo: saveButtonView.bottomAnchor),
            saveButtonView.button.leadingAnchor.constraint(equalTo: saveButtonView.leadingAnchor),
            saveButtonView.button.trailingAnchor.constraint(equalTo: saveButtonView.trailingAnchor),
        ])

        // PiP開始ボタン + 画面回転ボタンの座布団: タップエリアの拡張なし
        containerView.addSubview(pipOrientationBarView)

        // レーティング星 + カラーラベル: 保存ボタンの上のカプセル（レーティング有効時のみ）
        // 縦持ち/横持ちで配置が異なるため、両方の制約セットを用意しviewWillLayoutSubviewsで切り替える
        if isRatingEnabled {
            containerView.addSubview(ratingLabelBarView)
            containerView.addLayoutGuide(bottomBarGroupGuide)
            portraitBottomBarConstraints = [
                saveButtonView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                ratingLabelBarView.bottomAnchor.constraint(equalTo: saveButtonView.topAnchor, constant: -8),
                ratingLabelBarView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                // PiP+回転の座布団はレーティングバーの上、画面右端揃え
                pipOrientationBarView.bottomAnchor.constraint(equalTo: ratingLabelBarView.topAnchor, constant: -8),
                pipOrientationBarView.trailingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            ]
            landscapeBottomBarConstraints = [
                ratingLabelBarView.centerYAnchor.constraint(equalTo: saveButtonView.centerYAnchor),
                ratingLabelBarView.trailingAnchor.constraint(equalTo: saveButtonView.leadingAnchor, constant: -8),
                // PiP+回転の座布団は保存ボタンの右側
                pipOrientationBarView.centerYAnchor.constraint(equalTo: saveButtonView.centerYAnchor),
                pipOrientationBarView.leadingAnchor.constraint(equalTo: saveButtonView.trailingAnchor, constant: 8),
                // レーティングバー＋保存ボタン＋PiP/回転座布団の組をひとつのグループとみなし、左右中央に配置する
                bottomBarGroupGuide.leadingAnchor.constraint(equalTo: ratingLabelBarView.leadingAnchor),
                bottomBarGroupGuide.trailingAnchor.constraint(equalTo: pipOrientationBarView.trailingAnchor),
                bottomBarGroupGuide.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            ]
        } else {
            NSLayoutConstraint.activate([
                saveButtonView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            ])
            // 座布団が無い場合は、レーティングバーがあった分の余白を詰め、画面右端揃えで保存ボタンの真上に配置する
            portraitBottomBarConstraints = [
                pipOrientationBarView.bottomAnchor.constraint(equalTo: saveButtonView.topAnchor, constant: -8),
                pipOrientationBarView.trailingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            ]
            landscapeBottomBarConstraints = [
                pipOrientationBarView.centerYAnchor.constraint(equalTo: saveButtonView.centerYAnchor),
                pipOrientationBarView.leadingAnchor.constraint(equalTo: saveButtonView.trailingAnchor, constant: 8),
            ]
        }

        // ローディングインジケーター: 保存ボタン（レーティング有効時は星 + カラーラベル）の上
        containerView.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: saveButtonView.centerXAnchor),
        ])
        if isRatingEnabled {
            portraitBottomBarConstraints.append(
                loadingIndicator.bottomAnchor.constraint(equalTo: ratingLabelBarView.topAnchor, constant: -8)
            )
            landscapeBottomBarConstraints.append(
                loadingIndicator.bottomAnchor.constraint(equalTo: saveButtonView.topAnchor, constant: -8)
            )
        } else {
            NSLayoutConstraint.activate([
                loadingIndicator.bottomAnchor.constraint(equalTo: saveButtonView.topAnchor, constant: -8),
            ])
        }

        // 最終保存日時ラベル: 保存ボタンの下
        containerView.addSubview(lastSavedDateLabel)
        NSLayoutConstraint.activate([
            lastSavedDateLabel.topAnchor.constraint(equalTo: saveButtonView.bottomAnchor, constant: 4),
            lastSavedDateLabel.centerXAnchor.constraint(equalTo: saveButtonView.centerXAnchor),
        ])

        // 前へタッチ領域: 44×44のアイコンに対して左右下16pt・上8ptだけ拡張する。
        // 上をレーティングバーとの間隔(8pt)に合わせて重ならないようにしている。
        // ガラスボタンの上に重ねて前面に配置する。
        containerView.addSubview(prevHitAreaButton)
        NSLayoutConstraint.activate([
            prevHitAreaButton.leadingAnchor.constraint(equalTo: prevButtonView.leadingAnchor, constant: -16),
            prevHitAreaButton.trailingAnchor.constraint(equalTo: prevButtonView.trailingAnchor, constant: 16),
            prevHitAreaButton.topAnchor.constraint(equalTo: prevButtonView.topAnchor, constant: -8),
            prevHitAreaButton.bottomAnchor.constraint(equalTo: prevButtonView.bottomAnchor, constant: 16),
        ])

        // 次へタッチ領域: 44×44のアイコンに対して左右下16pt・上8ptだけ拡張する。
        // 上をレーティングバーとの間隔(8pt)に合わせて重ならないようにしている。
        // ガラスボタンの上に重ねて前面に配置する。
        containerView.addSubview(nextHitAreaButton)
        NSLayoutConstraint.activate([
            nextHitAreaButton.leadingAnchor.constraint(equalTo: nextButtonView.leadingAnchor, constant: -16),
            nextHitAreaButton.trailingAnchor.constraint(equalTo: nextButtonView.trailingAnchor, constant: 16),
            nextHitAreaButton.topAnchor.constraint(equalTo: nextButtonView.topAnchor, constant: -8),
            nextHitAreaButton.bottomAnchor.constraint(equalTo: nextButtonView.bottomAnchor, constant: 16),
        ])

        return BottomBarConstraints(portrait: portraitBottomBarConstraints, landscape: landscapeBottomBarConstraints)
    }
}
