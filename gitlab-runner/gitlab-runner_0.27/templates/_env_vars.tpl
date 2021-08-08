{{- define "gitlab-runner.runner-env-vars" }}
- name: CI_SERVER_URL
  value: {{ include "gitlab-runner.gitlabUrl" . }}
- name: CLONE_URL
  value: {{ default "" .Values.cloneUrl | quote }}
- name: RUNNER_REQUEST_CONCURRENCY
  value: {{ default 1 .Values.runners.requestConcurrency | quote }}
- name: RUNNER_EXECUTOR
  value: {{ default "kubernetes" .Values.runners.executor | quote }}
- name: REGISTER_LOCKED
  value: {{ default "true" .Values.locked | quote }}
- name: RUNNER_TAG_LIST
  value: {{ default "" .Values.tags | quote }}
{{- if .Values.runners.outputLimit }}
- name: RUNNER_OUTPUT_LIMIT
  value: {{ .Values.runners.outputLimit | quote }}
{{- end}}
{{- if eq (default "kubernetes" .Values.runners.executor) "kubernetes" }}
- name: KUBERNETES_IMAGE
  value: {{ .Values.runners.image | quote }}
{{ if .Values.runners.privileged }}
- name: KUBERNETES_PRIVILEGED
  value: "true"
{{ end }}
- name: KUBERNETES_NAMESPACE
  value: {{ default .Release.Namespace .Values.runners.namespace | quote }}
{{- if .Values.runners.pollTimeout}}
- name: KUBERNETES_POLL_TIMEOUT
  value: {{ .Values.runners.pollTimeout | quote }}
{{- end }}
- name: KUBERNETES_CPU_LIMIT
  value: {{ default "" .Values.runners.builds.cpuLimit | quote }}
- name: KUBERNETES_CPU_LIMIT_OVERWRITE_MAX_ALLOWED
  value: {{ default "" .Values.runners.builds.cpuLimitOverwriteMaxAllowed | quote }}
- name: KUBERNETES_MEMORY_LIMIT
  value: {{ default "" .Values.runners.builds.memoryLimit | quote }}
- name: KUBERNETES_MEMORY_LIMIT_OVERWRITE_MAX_ALLOWED
  value: {{ default "" .Values.runners.builds.memoryLimitOverwriteMaxAllowed | quote }}
- name: KUBERNETES_CPU_REQUEST
  value: {{ default "" .Values.runners.builds.cpuRequests | quote }}
- name: KUBERNETES_CPU_REQUEST_OVERWRITE_MAX_ALLOWED
  value: {{ default "" .Values.runners.builds.cpuRequestsOverwriteMaxAllowed | quote }}
- name: KUBERNETES_MEMORY_REQUEST
  value: {{ default "" .Values.runners.builds.memoryRequests| quote }}
- name: KUBERNETES_MEMORY_REQUEST_OVERWRITE_MAX_ALLOWED
  value: {{ default "" .Values.runners.builds.memoryRequestsOverwriteMaxAllowed | quote }}
- name: KUBERNETES_SERVICE_ACCOUNT
  value: {{ default "" .Values.runners.serviceAccountName | quote }}
- name: KUBERNETES_SERVICE_CPU_LIMIT
  value: {{ default "" .Values.runners.services.cpuLimit | quote }}
- name: KUBERNETES_SERVICE_MEMORY_LIMIT
  value: {{ default "" .Values.runners.services.memoryLimit | quote }}
- name: KUBERNETES_SERVICE_CPU_REQUEST
  value: {{ default "" .Values.runners.services.cpuRequests | quote }}
- name: KUBERNETES_SERVICE_MEMORY_REQUEST
  value: {{ default "" .Values.runners.services.memoryRequests | quote }}
- name: KUBERNETES_HELPER_CPU_LIMIT
  value: {{ default "" .Values.runners.helpers.cpuLimit | quote }}
- name: KUBERNETES_HELPER_MEMORY_LIMIT
  value: {{ default "" .Values.runners.helpers.memoryLimit | quote }}
- name: KUBERNETES_HELPER_CPU_REQUEST
  value: {{ default "" .Values.runners.helpers.cpuRequests | quote }}
- name: KUBERNETES_HELPER_MEMORY_REQUEST
  value: {{ default "" .Values.runners.helpers.memoryRequests | quote }}
- name: KUBERNETES_HELPER_IMAGE
  value: {{ default "" .Values.runners.helpers.image | quote }}
- name: KUBERNETES_PULL_POLICY
  value: {{ default "" .Values.runners.imagePullPolicy | quote }}
{{- if .Values.runners.pod_security_context }}
{{-   if .Values.runners.pod_security_context.run_as_non_root }}
- name: KUBERNETES_POD_SECURITY_CONTEXT_RUN_AS_NON_ROOT
  value: "true"
{{-   end }}
{{-   if .Values.runners.pod_security_context.run_as_user }}
- name: KUBERNETES_POD_SECURITY_CONTEXT_RUN_AS_USER
  value: {{ .Values.runners.pod_security_context.run_as_user | quote }}
{{-   end }}
{{-   if .Values.runners.pod_security_context.run_as_group }}
- name: KUBERNETES_POD_SECURITY_CONTEXT_RUN_AS_GROUP
  value: {{ .Values.runners.pod_security_context.run_as_group | quote }}
{{-   end }}
{{-   if .Values.runners.pod_security_context.fs_group }}
- name: KUBERNETES_POD_SECURITY_CONTEXT_FS_GROUP
  value: {{ .Values.runners.pod_security_context.fs_group | quote }}
{{-   end }}
{{- end }}
{{- end }}
{{- if .Values.runners.cache -}}
{{ include "gitlab-runner.cache" . }}
{{- end }}
{{- if .Values.envVars -}}
{{ range .Values.envVars }}
- name: {{ .name }}
  value: {{ .value | quote }}
{{- end }}
{{- end }}
{{- end }}
