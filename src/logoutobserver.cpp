/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include "logoutobserver.h"
#include "leakdetector.h"
#include "mozillavpn.h"

LogoutObserver::LogoutObserver(QObject *parent) : QObject(parent)
{
    MVPN_COUNT_CTOR(LogoutObserver);

    MozillaVPN *vpn = MozillaVPN::instance();
    Q_ASSERT(vpn->userAuthenticated());

    connect(vpn, &MozillaVPN::userAuthenticationChanged, this, &LogoutObserver::userAuthenticationChanged);
}

LogoutObserver::~LogoutObserver()
{
    MVPN_COUNT_DTOR(LogoutObserver);
}

void LogoutObserver::userAuthenticationChanged() {
        MozillaVPN *vpn = MozillaVPN::instance();
        if (!vpn->userAuthenticated()) {
            emit ready();
            deleteLater();
        }
}
