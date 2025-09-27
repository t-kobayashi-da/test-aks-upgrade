{{- define "nginx.name" -}}
{{ .Chart.Name }}
{{- end -}}

{{- define "nginx.fullname" -}}
{{ .Release.Name }}-{{ .Chart.Name }}
{{- end -}}
