/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef ANDROIDAPPIMAGEPROVIDER_H
#define ANDROIDAPPIMAGEPROVIDER_H

#include <QObject>
#include <QQuickImageProvider>
#include <QAndroidJniObject>

class AndroidAppImageProvider : public QQuickImageProvider, public QObject {
 public:
  AndroidAppImageProvider(QObject* parent);
  ~AndroidAppImageProvider();
  QImage requestImage(const QString& id, QSize* size,
                      const QSize& requestedSize) override;

  QAndroidJniObject createBitmap(int width, int height);
  QImage toImage(const QAndroidJniObject& bitmap);
  QImage toImage(const QAndroidJniObject& drawable, const QRect& bounds);
};

#endif  // ANDROIDAPPIMAGEPROVIDER_H
