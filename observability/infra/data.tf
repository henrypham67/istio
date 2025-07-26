data "aws_lb" "istio_gateway" {
  depends_on = [kubectl_manifest.virtual_service]

  name = "istio-gateway-lb"
}