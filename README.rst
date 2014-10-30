Dyno
====

A simple RESTful API content service via `openresty <http://openresty.org/>`_, use basic HTTP auth.

Quickstart
``````````

.. code-block:: sh

    redis-cli -n 0 hkeys auth{dyno} username passwd
    redis-cli -n 0 sadd allowed{assets.example.com} username

    curl -i -X POST --user username:passwd \
    http://127.0.0.1:8000/about \
        --header 'Host: assets.example.com' \
        --data "content_type=application/octet-stream&body=test only"

    curl -i -X GET --user username:passwd \
        http://127.0.0.1:8000/about \
        --header 'Host: assets.example.com'
    # or

    curl http://assets.example.com/about

.. code-block:: python

    import requests
    payload = {
        'content_type': 'application/octet-stream',
        'body': 'test only',
    }
    headers = {'Host': 'assets.example.com'}
    auth = ('username', 'passwd')
    url = 'http://127.0.0.1:8000/about'
    response = requests.post(url, data=payload, headers=headers, auth=auth)
    assert response.status_code in (200, 201), 'status_code {}'.format(response.status_code)
