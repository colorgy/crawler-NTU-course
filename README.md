臺大課程爬蟲
===========

還沒重構完就研究好害羞啊 >///<

## Deployments

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

1.
```
    GET /courses.json
```
用 redis 存


2.
```
    GET /sidekiq
```
sidekiq 的 web monitor

3.
```
    GET /?key=api_key_here
```
讓他開始跑 task

4.
```
    GET/force?key=api_key_here
```
強制重跑 task，<del>預設間隔為兩小時</del>(還沒弄)

## Devlopement

```
    bundle
    cp .sample.env .env
    redis-server /usr/local/etc/redis.conf # make sure you've install redis
    foreman start
```
