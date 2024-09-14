#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# -e 如果脚本中有错误就会终止向下运行(如果不加则会继续向下执行)，-u 所有未定义的变量视为错误
set -eu

# 这段脚本主要用于解析软链接（Symbolic Link），找到脚本文件的实际位置。脚本中使用了循环结构，逐步解析软链接直到找到真实的文件路径
# $0 表示当前执行的脚本名称（或路径）。
# PRG="$0" 的作用是将脚本的路径或名称赋值给变量 PRG，作为初始值
PRG="$0"
# [ -h "$PRG" ] 是一个条件检查，用于判断 PRG 是否是一个符号链接（软链接）。-h 选项检查路径是否是一个符号链接。
# while 表示这是一个循环语句，只要 PRG 是软链接，循环就会继续。整个 while 循环会不断执行，直到 PRG 不是符号链接（即 PRG 指向了实际的文件，而不是另一个符号链接）
while [ -h "$PRG" ] ; do
  # ls -ld "$PRG" 列出符号链接文件的详细信息（不跟随链接，显示符号链接本身）。
  #     -l：显示详细信息。
  #     -d：如果文件是目录，则只显示目录本身的信息，而不是目录内容。
  # ls= 将输出结果赋给变量 ls，这个结果是符号链接的详细信息。
  # 如果 PRG 是软链接，输出可能类似于：lrwxrwxrwx 1 user group 10 Jun 15 12:00 myscript.sh -> /real/path/script.sh
  ls=`ls -ld "$PRG"`
  # 解析链接目标
  # expr 是一个命令行工具，用于字符串操作。在这里，它用于从 ls 输出中提取符号链接指向的实际路径。
  #     expr "$ls" : '.*-> \(.*\)$' 使用正则表达式匹配并提取 -> 之后的内容，即符号链接指向的路径。
  #     \(.*\) 捕获链接目标的路径。
  # 这个命令将提取到的实际路径赋给变量 link
  link=`expr "$ls" : '.*-> \(.*\)$'`
  # 检查链接目标路径
  # 这部分的逻辑用于处理两种不同类型的符号链接目标：绝对路径和相对路径。
  # 这个条件检查 link 是否是以 / 开头，即是否是绝对路径。expr "$link" : '/.*' 用于判断路径是否是绝对路径，如果是绝对路径，返回非零状态。
  if expr "$link" : '/.*' > /dev/null; then
    # 如果 link 是绝对路径，直接将 link 赋给 PRG，即 PRG 现在指向了实际的文件路径
    PRG="$link"
  else
    # 如果 link 是相对路径，PRG 需要通过 dirname "$PRG" 获取软链接所在的目录，然后与 link 进行拼接，形成一个完整的路径。
    # dirname "$PRG" 返回 PRG 的父目录路径，这样可以处理相对路径的情况
    PRG=`dirname "$PRG"`/"$link"
  fi
done
# dirname "$PRG" 是用于获取 PRG（即脚本的实际位置）的父目录路径。
#   如果 PRG 是 /path/to/script.sh，那么 PRG_DIR 会变成 /path/to。通过这一步，脚本获取了它所在的目录。
PRG_DIR=`dirname "$PRG"`
# cd "$PRG_DIR/.." 表示从 PRG_DIR 路径向上一级目录。如果 PRG_DIR 是 /path/to，那么 cd "$PRG_DIR/.." 就会进入 /path。
# pwd 用于获取当前工作目录的绝对路径。
# >/dev/null 将 cd 和 pwd 命令的输出重定向到空设备（忽略输出）。
# 最终，APP_DIR 会被设置为脚本所在目录的上一级目录的绝对路径。假设脚本位于 /path/to/script.sh，那么 APP_DIR 会被设置为 /path
APP_DIR=`cd "$PRG_DIR/.." >/dev/null; pwd`
CONF_DIR=${APP_DIR}/config
# 变量赋值
APP_JAR=${APP_DIR}/starter/seatunnel-flink-15-starter.jar
# 变量赋值
APP_MAIN="org.apache.seatunnel.core.starter.flink.FlinkStarter"
# 执行环境变量脚本
if [ -f "${CONF_DIR}/seatunnel-env.sh" ]; then
    . "${CONF_DIR}/seatunnel-env.sh"
fi
# 传参
if [ $# == 0 ]
then
    args="-h"
else
    args=$@
fi
# 与 -u 相反
set +u
# Log4j2 Config
if [ -e "${CONF_DIR}/log4j2.properties" ]; then
  JAVA_OPTS="${JAVA_OPTS} -Dlog4j2.configurationFile=${CONF_DIR}/log4j2.properties"
  JAVA_OPTS="${JAVA_OPTS} -Dseatunnel.logs.path=${APP_DIR}/logs"
  JAVA_OPTS="${JAVA_OPTS} -Dseatunnel.logs.file_name=seatunnel-flink-starter"
fi

CLASS_PATH=${APP_DIR}/starter/logging/*:${APP_JAR}
# CMD=$(...)：使用 $() 运行括号内的命令，并将其标准输出结果赋值给变量 CMD
# && EXIT_CODE=$? || EXIT_CODE=$?：在命令执行后，通过 $? 来获取命令的退出状态码，并将其赋值给 EXIT_CODE。
#   如果 Java 程序成功执行，退出状态码为 0，则通过 && 操作将 EXIT_CODE 设置为 0。
#   如果执行失败，则通过 || 操作获取失败的退出状态码并赋值给 EXIT_CODE。
CMD=$(java ${JAVA_OPTS} -cp ${CLASS_PATH} ${APP_MAIN} ${args}) && EXIT_CODE=$? || EXIT_CODE=$?
if [ ${EXIT_CODE} -eq 234 ]; then
    # print usage
    # EXIT_CODE = 234：打印帮助信息（可能是程序的用法说明），然后正常退出。
    echo "${CMD}"
    exit 0
elif [ ${EXIT_CODE} -eq 0 ]; then
    # EXIT_CODE = 0：成功执行任务，打印最后的执行命令，并执行实际的 Flink Job。
    echo "Execute SeaTunnel Flink Job: $(echo "${CMD}" | tail -n 1)"
    eval $(echo "${CMD}" | tail -n 1)
else
    # 其他 EXIT_CODE：打印错误信息，并使用非零退出码结束脚本，标识错误。
    echo "${CMD}"
    exit ${EXIT_CODE}
fi
