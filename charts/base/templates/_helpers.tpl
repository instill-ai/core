{{/*
Expand the name of the chart.
*/}}
{{- define "base.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "base.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Allow the release namespace to be overridden for multi-namespace deployments in combined charts
*/}}
{{- define "base.namespace" -}}
  {{- if .Values.namespaceOverride -}}
    {{- .Values.namespaceOverride -}}
  {{- else -}}
    {{- .Release.Namespace -}}
  {{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "base.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "base.labels" -}}
app.kubernetes.io/name: {{ include "base.name" . }}
helm.sh/chart: {{ include "base.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | replace "+" "_" }}
app.kubernetes.io/part-of: {{ .Chart.Name }}
{{- end -}}

{{/*
MatchLabels
*/}}
{{- define "base.matchLabels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/name: {{ include "base.name" . }}
{{- end -}}

{{- define "base.autoGenCert" -}}
  {{- if and .Values.expose.tls.enabled (eq .Values.expose.tls.certSource "auto") -}}
    {{- printf "true" -}}
  {{- else -}}
    {{- printf "false" -}}
  {{- end -}}
{{- end -}}

{{- define "base.autoGenCertForIngress" -}}
  {{- if and (eq (include "base.autoGenCert" .) "true") (eq .Values.expose.type "ingress") -}}
    {{- printf "true" -}}
  {{- else -}}
    {{- printf "false" -}}
  {{- end -}}
{{- end -}}

{{- define "base.database.host" -}}
  {{- if .Values.database.enabled -}}
    {{- template "base.database" . -}}
  {{- else -}}
    {{- .Values.database.external.host -}}
  {{- end -}}
{{- end -}}

{{- define "base.database.port" -}}
  {{- if .Values.database.enabled -}}
    {{- printf "%s" "5432" -}}
  {{- else -}}
    {{- .Values.database.external.port -}}
  {{- end -}}
{{- end -}}

{{- define "base.database.username" -}}
  {{- if .Values.database.enabled -}}
    {{- printf "%s" "postgres" -}}
  {{- else -}}
    {{- .Values.database.external.username -}}
  {{- end -}}
{{- end -}}

{{- define "base.database.rawPassword" -}}
  {{- if .Values.database.enabled -}}
    {{- .Values.database.password -}}
  {{- else -}}
    {{- .Values.database.external.password -}}
  {{- end -}}
{{- end -}}

{{- define "base.database.encryptedPassword" -}}
  {{- include "base.database.rawPassword" . | b64enc | quote -}}
{{- end -}}

{{- define "base.redis.scheme" -}}
  {{- with .Values.redis -}}
    {{- ternary "redis+sentinel" "redis"  (and (eq .type "external" ) .external.sentinelMasterSet) -}}
  {{- end -}}
{{- end -}}

/*host:port*/
{{- define "base.redis.addr" -}}
  {{- with .Values.redis -}}
    {{- ternary (printf "%s:6379" (include "base.redis" $ )) .external.addr .enabled -}}
  {{- end -}}
{{- end -}}

{{- define "base.redis.masterSet" -}}
  {{- with .Values.redis -}}
    {{- ternary .external.sentinelMasterSet "" (eq "redis+sentinel" (include "base.redis.scheme" $)) -}}
  {{- end -}}
{{- end -}}

{{- define "base.redis.password" -}}
  {{- with .Values.redis -}}
    {{- ternary "" .external.password .enabled -}}
  {{- end -}}
{{- end -}}

/*scheme://[:password@]host:port[/master_set]*/
{{- define "base.redis.url" -}}
  {{- with .Values.redis -}}
    {{- $path := ternary "" (printf "/%s" (include "base.redis.masterSet" $)) (not (include "base.redis.masterSet" $)) -}}
    {{- $cred := ternary (printf ":%s@" (.external.password | urlquery)) "" (and (eq .type "external" ) (not (not .external.password))) -}}
    {{- printf "%s://%s%s%s" (include "base.redis.scheme" $) $cred (include "base.redis.addr" $) $path -}}
  {{- end -}}
{{- end -}}

{{- define "base.apigateway" -}}
  {{- printf "%s-apigateway" (include "base.fullname" .) -}}
{{- end -}}

{{- define "base.mgmt" -}}
  {{- printf "%s-mgmt-backend" (include "base.fullname" .) -}}
{{- end -}}

{{- define "base.mgmt.migration" -}}
  {{- printf "%s-mgmt-backend-migration" (include "base.mgmt" .) -}}
{{- end -}}

{{- define "base.console" -}}
  {{- printf "%s-console" (include "base.fullname" .) -}}
{{- end -}}

{{- define "base.database" -}}
  {{- printf "%s-database" (include "base.fullname" .) -}}
{{- end -}}

{{- define "base.redis" -}}
  {{- printf "%s-redis" (include "base.fullname" .) -}}
{{- end -}}

{{- define "base.temporal" -}}
  {{- printf "%s-temporal" (include "base.fullname" .) -}}
{{- end -}}

{{- define "base.etcd" -}}
  {{- printf "%s-etcd" (include "base.fullname" .) -}}
{{- end -}}

{{- define "base.temporal.admintools" -}}
  {{- printf "%s-temporal-admintools" (include "base.fullname" .) -}}
{{- end -}}

{{- define "base.temporal.ui" -}}
  {{- printf "%s-temporal-ui" (include "base.fullname" .) -}}
{{- end -}}

{{/* api-gateway service and container port */}}
{{- define "base.apigateway.httpPort" -}}
  {{- printf "8080" -}}
{{- end -}}

{{/* api-gateway service and container stats port */}}
{{- define "base.apigateway.statsPort" -}}
  {{- printf "8090" -}}
{{- end -}}

{{/* api-gateway service and container metrics port */}}
{{- define "base.apigateway.metricsPort" -}}
  {{- printf "9000" -}}
{{- end -}}

{{/* mgmt service and container public port */}}
{{- define "base.mgmt.publicPort" -}}
  {{- printf "8084" -}}
{{- end -}}

{{/* mgmt service and container private port */}}
{{- define "base.mgmt.privatePort" -}}
  {{- printf "3084" -}}
{{- end -}}

{{/* console service and container port */}}
{{- define "base.console.port" -}}
  {{- printf "3000" -}}
{{- end -}}

{{/* temporal container frontend gRPC port */}}
{{- define "base.temporal.frontend.grpcPort" -}}
  {{- printf "7233" -}}
{{- end -}}

{{/* temporal container frontend membership port */}}
{{- define "base.temporal.frontend.membershipPort" -}}
  {{- printf "6933" -}}
{{- end -}}

{{/* temporal container history gRPC port */}}
{{- define "base.temporal.history.grpcPort" -}}
  {{- printf "7234" -}}
{{- end -}}

{{/* temporal container history membership port */}}
{{- define "base.temporal.history.membershipPort" -}}
  {{- printf "6934" -}}
{{- end -}}

{{/* temporal container matching gRPC port */}}
{{- define "base.temporal.matching.grpcPort" -}}
  {{- printf "7235" -}}
{{- end -}}

{{/* temporal container matching membership port */}}
{{- define "base.temporal.matching.membershipPort" -}}
  {{- printf "6935" -}}
{{- end -}}

{{/* temporal container worker gRPC port */}}
{{- define "base.temporal.worker.grpcPort" -}}
  {{- printf "7239" -}}
{{- end -}}

{{/* temporal container worker membership port */}}
{{- define "base.temporal.worker.membershipPort" -}}
  {{- printf "6939" -}}
{{- end -}}

{{/* temporal web container port */}}
{{- define "base.temporal.ui.port" -}}
  {{- printf "8080" -}}
{{- end -}}

{{/* etcd port */}}
{{- define "base.etcd.clientPort" -}}
  {{- printf "2379" -}}
{{- end -}}

{{- define "base.etcd.peerPort" -}}
  {{- printf "2380" -}}
{{- end -}}

{{- define "base.influxdb" -}}
  {{- printf "base-influxdb2" -}}
{{- end -}}

{{- define "base.influxdb.port" -}}
  {{- printf "8086" -}}
{{- end -}}

{{- define "base.jaeger" -}}
  {{- printf "base-jaeger-collector" -}}
{{- end -}}

{{- define "base.jaeger.port" -}}
  {{- printf "14268" -}}
{{- end -}}

{{- define "base.otel" -}}
  {{- printf "base-opentelemetry-collector" -}}
{{- end -}}

{{- define "base.otel.port" -}}
  {{- printf "8095" -}}
{{- end -}}

{{- define "base.internalTLS.apigateway.secretName" -}}
  {{- if eq .Values.internalTLS.certSource "secret" -}}
    {{- .Values.internalTLS.apigateway.secretName -}}
  {{- else -}}
    {{- printf "%s-apigateway-internal-tls" (include "base.fullname" .) -}}
  {{- end -}}
{{- end -}}

{{- define "base.internalTLS.controller.secretName" -}}
  {{- if eq .Values.internalTLS.certSource "secret" -}}
    {{- .Values.internalTLS.controller.secretName -}}
  {{- else -}}
    {{- printf "%s-controller-internal-tls" (include "base.fullname" .) -}}
  {{- end -}}
{{- end -}}

{{- define "base.internalTLS.mgmt.secretName" -}}
  {{- if eq .Values.internalTLS.certSource "secret" -}}
    {{- .Values.internalTLS.mgmt.secretName -}}
  {{- else -}}
    {{- printf "%s-mgmt-internal-tls" (include "base.fullname" .) -}}
  {{- end -}}
{{- end -}}

{{- define "base.internalTLS.console.secretName" -}}
  {{- if eq .Values.internalTLS.certSource "secret" -}}
    {{- .Values.internalTLS.console.secretName -}}
  {{- else -}}
    {{- printf "%s-console-internal-tls" (include "base.fullname" .) -}}
  {{- end -}}
{{- end -}}

{{/* Allow KubeVersion to be overridden. */}}
{{- define "base.ingress.kubeVersion" -}}
  {{- default .Capabilities.KubeVersion.Version .Values.expose.ingress.kubeVersionOverride -}}
{{- end -}}
