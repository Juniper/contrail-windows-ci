def call(vmRole = null) {

  def folder = null
  if (env.VC_FOLDER) {
    folder = env.VC_FOLDER
  }

  def template = null
  if (env.VM_TEMPLATE) {
    template = env.VM_TEMPLATE
  }

  def baseVMParams = [vcenter_user: env.VC_USR,
                      vcenter_password: env.VC_PSW,
                      validate_certs: 'no']

  if (folder) {
    baseVMParams.vmware_folder = folder
  }

  if (template) {
    baseVMParams.vm_template = template
  }

  if (vmRole) {
    baseVMParams.vm_role = vmRole
  }

  return baseVMParams
}
