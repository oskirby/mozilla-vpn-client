/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef ADDONAPI_H
#define ADDONAPI_H

#include "frontend/navigator.h"
#include "settingsholder.h"

#include <QJSValue>
#include <QObject>

class Addon;

/*
 * IMPORTANT!! If you add, change or remove this object, please update the
 * documentation in `docs/add-on-api.md`.
 */

class AddonApi final : public QObject {
  Q_OBJECT
  Q_DISABLE_COPY_MOVE(AddonApi)

  Q_PROPERTY(QJSValue settings READ settings CONSTANT)
  Q_PROPERTY(QJSValue navigator READ navigator CONSTANT)

 public:
  explicit AddonApi(Addon* addon);
  ~AddonApi();

  Q_INVOKABLE void connectSignal(QObject* obj, const QString& signalName,
                                 const QJSValue& callback);

  Q_INVOKABLE void openURL(const QString& url) const;

 private:
  explicit AddonApi(QObject* parent);

  QJSValue settings() const;
  QJSValue navigator() const;
};

class AddonApiCallbackWrapper final : public QObject {
  Q_OBJECT

 public:
  AddonApiCallbackWrapper(QObject* parent, const QJSValue& callback);

 public slots:
  void run();

 private:
  const QJSValue m_callback;
};

#endif  // ADDONAPI_H