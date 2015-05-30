臺大課程爬蟲
===========

還沒重構完就研究好害羞啊 >///<

## Deployments

一鍵 Deploy
[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy?template=https://github.com/colorgy/crawler-NTU-course/tree/master)

Deploy 後把 clone 下來的 app 連結到 heroku

```
git remote add heroku git@heroku.com:your_project_name.git
```

去 dashboard 把 dyno type 設成 free 然後跑

```
    heroku ps:scale worker=1
```


## Endpoints


## Devlopement

```
    git clone this_project_git_url
    bundle
    cp .sample.env .env
    redis-server /usr/local/etc/redis.conf # make sure you've install redis
    foreman start
```
