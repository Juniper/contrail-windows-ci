def call(vmRole = null) {
  def baseVMParams = [vcenter_user: env.VC_USR,
                      vcenter_password: env.VC_PSW,
                      validate_certs: 'no']

  if (env.VC_FOLDER) {
    baseVMParams.vmware_folder = env.VC_FOLDER
  }

  if (env.VM_TEMPLATE) {
    baseVMParams.vm_template = env.VM_TEMPLATE
  }

  if (vmRole) {
    baseVMParams.vm_role = vmRole
  }

  if (env.VM_ROLE_SUFFIX) {
    baseVMParams.vm_role_suffix = env.VM_ROLE_SUFFIX
  }

  return baseVMParams
}
