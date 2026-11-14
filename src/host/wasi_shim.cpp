#include "host_api.h"

#include <cstring>
#include <wasi/api.h>

extern "C" {

__wasi_errno_t __wasi_environ_sizes_get(__wasi_size_t *environ_count,
                                        __wasi_size_t *environ_buf_size) {
  *environ_count = 0;
  *environ_buf_size = 0;
  return __WASI_ERRNO_SUCCESS;
}

__wasi_errno_t __wasi_environ_get(uint8_t **environ, uint8_t *environ_buf) {
  (void)environ;
  (void)environ_buf;
  return __WASI_ERRNO_SUCCESS;
}

__wasi_errno_t __wasi_fd_write(__wasi_fd_t fd, const __wasi_ciovec_t *iovs, size_t iovs_len,
                               __wasi_size_t *retptr0) {
  size_t written = 0;
  if (fd == 1 || fd == 2) {
    for (size_t i = 0; i < iovs_len; i++) {
      auto msg = std::string_view(reinterpret_cast<const char *>(iovs[i].buf), iovs[i].buf_len);
      if (!msg.empty()) {
        host_api::log(msg);
      }
      written += iovs[i].buf_len;
    }
    *retptr0 = written;
    return __WASI_ERRNO_SUCCESS;
  }
  return __WASI_ERRNO_BADF;
}

__wasi_errno_t __wasi_random_get(uint8_t *buf, __wasi_size_t buf_len) {
  auto *out = buf;
  size_t offset = 0;
  while (offset < buf_len) {
    auto rnd = host_api::Random::get_u32().unwrap();
    size_t n = std::min(sizeof(rnd), buf_len - offset);
    std::memcpy(out + offset, &rnd, n);
    offset += n;
  }
  return __WASI_ERRNO_SUCCESS;
}

__wasi_errno_t __wasi_clock_time_get(__wasi_clockid_t id, __wasi_timestamp_t precision,
                                     __wasi_timestamp_t *time) {
  (void)id;
  (void)precision;
  static __wasi_timestamp_t now = 0;
  now += 1000000;
  *time = now;
  return __WASI_ERRNO_SUCCESS;
}

__wasi_errno_t __wasi_fd_close(__wasi_fd_t fd) {
  (void)fd;
  return __WASI_ERRNO_SUCCESS;
}

__wasi_errno_t __wasi_fd_fdstat_get(__wasi_fd_t fd, __wasi_fdstat_t *retptr0) {
  std::memset(retptr0, 0, sizeof(*retptr0));
  retptr0->fs_filetype = __WASI_FILETYPE_CHARACTER_DEVICE;
  return (fd <= 2) ? __WASI_ERRNO_SUCCESS : __WASI_ERRNO_BADF;
}

__wasi_errno_t __wasi_fd_fdstat_set_flags(__wasi_fd_t fd, __wasi_fdflags_t flags) {
  (void)fd;
  (void)flags;
  return __WASI_ERRNO_SUCCESS;
}

__wasi_errno_t __wasi_fd_prestat_get(__wasi_fd_t fd, __wasi_prestat_t *retptr0) {
  (void)fd;
  (void)retptr0;
  return __WASI_ERRNO_BADF;
}

__wasi_errno_t __wasi_fd_prestat_dir_name(__wasi_fd_t fd, uint8_t *path, __wasi_size_t path_len) {
  (void)fd;
  (void)path;
  (void)path_len;
  return __WASI_ERRNO_BADF;
}

__wasi_errno_t __wasi_fd_read(__wasi_fd_t fd, const __wasi_iovec_t *iovs, size_t iovs_len,
                              __wasi_size_t *retptr0) {
  (void)fd;
  (void)iovs;
  (void)iovs_len;
  *retptr0 = 0;
  return __WASI_ERRNO_BADF;
}

__wasi_errno_t __wasi_fd_seek(__wasi_fd_t fd, __wasi_filedelta_t offset, __wasi_whence_t whence,
                              __wasi_filesize_t *retptr0) {
  (void)fd;
  (void)offset;
  (void)whence;
  *retptr0 = 0;
  return __WASI_ERRNO_BADF;
}

__wasi_errno_t __wasi_path_filestat_get(__wasi_fd_t fd, __wasi_lookupflags_t flags,
                                        const char *path, __wasi_filestat_t *retptr0) {
  (void)fd;
  (void)flags;
  (void)path;
  (void)retptr0;
  return __WASI_ERRNO_NOENT;
}

__wasi_errno_t __wasi_path_open(__wasi_fd_t fd, __wasi_lookupflags_t dirflags, const char *path,
                                __wasi_oflags_t oflags, __wasi_rights_t fs_rights_base,
                                __wasi_rights_t fs_rights_inheriting, __wasi_fdflags_t fdflags,
                                __wasi_fd_t *retptr0) {
  (void)fd;
  (void)dirflags;
  (void)path;
  (void)oflags;
  (void)fs_rights_base;
  (void)fs_rights_inheriting;
  (void)fdflags;
  *retptr0 = -1;
  return __WASI_ERRNO_NOENT;
}

__wasi_errno_t __wasi_path_remove_directory(__wasi_fd_t fd, const char *path) {
  (void)fd;
  (void)path;
  return __WASI_ERRNO_NOENT;
}

__wasi_errno_t __wasi_path_unlink_file(__wasi_fd_t fd, const char *path) {
  (void)fd;
  (void)path;
  return __WASI_ERRNO_NOENT;
}

void __wasi_proc_exit(__wasi_exitcode_t rval) {
  (void)rval;
  __builtin_trap();
}

} // extern "C"
