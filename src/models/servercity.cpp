/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include "servercity.h"
#include "leakdetector.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QJsonValue>

ServerCity::ServerCity()
{
    MVPN_COUNT_CTOR(ServerCity);
}

ServerCity::ServerCity(const ServerCity &other)
{
    MVPN_COUNT_CTOR(ServerCity);
    m_name = other.m_name;
    m_code = other.m_code;
    m_servers = other.m_servers;
}

ServerCity::~ServerCity()
{
    MVPN_COUNT_DTOR(ServerCity);
}

bool ServerCity::fromJson(QJsonObject &obj)
{
    QJsonValue name = obj.take("name");
    if (!name.isString()) {
        return false;
    }

    QJsonValue code = obj.take("code");
    if (!code.isString()) {
        return false;
    }

    QJsonValue serversValue = obj.take("servers");
    if (!serversValue.isArray()) {
        return false;
    }

    QList<Server> servers;
    QJsonArray serversArray = serversValue.toArray();
    for (QJsonValue serverValue : serversArray) {
        if (!serverValue.isObject()) {
            return false;
        }

        QJsonObject serverObj = serverValue.toObject();

        Server server;
        if (!server.fromJson(serverObj)) {
            return false;
        }

        servers.append(server);
    }

    m_name = name.toString();
    m_code = code.toString();
    m_servers.swap(servers);

    return true;
}
