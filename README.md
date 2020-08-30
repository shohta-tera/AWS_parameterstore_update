# AWS_parameterstore_update

AWS リソースのパラメータをパラメータストアに格納し、それの変化を検知し自動的にアップデートするものです。

## Directory

```
home
├ src
  ├ CFnUpdate: 実際にCFnをアップデートするためのソース
  └ Customer: 自動でCFnをアップデートする用のLambdaに使用するコード
├ Template: CFn一覧
├ Makefile
...
```

## Command List

`make create.bucket`

- 各種 AWS リソースデプロイ時にソース類をアップロードする S3 バケット

`make create.layer`

- 必要な Lambda Layer をデプロイする

`make sam.package → make sam.deploy`

- CFn を自動でアップデートするアプリケーションをデプロイする

`make deploy → make test.package → make test.deploy`

- 検証用のサンプルアプリケーションのデプロイ

### Enviroment Variable

- ENV_NAME
  - CFn のスタック名の頭に付与する名前
- PHASE
  - dev, stage, prod の三種類
  - リソースの自動更新を検証する場合は prod
- WEBHOOKURL
  - サンプルでは、slack, Teams などの WebHookURL をパラメータストアのセキュアストリングに格納します。
  - 特定の物がなければ、単に文字列でも大丈夫です。
