NGPU_PER_NODE=16
MODEL_FILE="./ckpt/bert-large-uncased-whole-word-masking-pytorch_model.bin"
ORIGIN_CONFIG_FILE="./ckpt/bert-large-uncased-whole-word-masking-config.json"
SQUAD_DIR="./data"
OUTPUT_DIR=$1
LR=4e-5
SEED=$RANDOM
MASTER_PORT=12345
DROPOUT=0.09

sudo rm -rf ${OUTPUT_DIR}

# Force deepspeed to run with only local node
NUM_NODES=1
HOSTFILE=hosts

NGPU=$((NGPU_PER_NODE*NUM_NODES))
EFFECTIVE_BATCH_SIZE=96
MAX_GPU_BATCH_SIZE=3
PER_GPU_BATCH_SIZE=$((EFFECTIVE_BATCH_SIZE/NGPU))
if [[ $PER_GPU_BATCH_SIZE -lt $MAX_GPU_BATCH_SIZE ]]; then
       GRAD_ACCUM_STEPS=1
else
       GRAD_ACCUM_STEPS=$((PER_GPU_BATCH_SIZE/MAX_GPU_BATCH_SIZE))
fi
JOB_NAME="onebit_deepspeed_${NGPU}GPUs_${EFFECTIVE_BATCH_SIZE}batch_size"
config_json=onebit_deepspeed_bsz24_config.json
#run_cmd="deepspeed --num_nodes ${NUM_NODES} --num_gpus ${NGPU_PER_NODE} \
#       --master_port=${MASTER_PORT} \
run_cmd="python3.6 \
       nvidia_run_squad_deepspeed.py \
       --bert_model bert-large-uncased \
       --do_train \
       --do_lower_case \
       --predict_batch_size 3 \
       --do_predict \
       --train_file $SQUAD_DIR/train-v1.1.json \
       --predict_file $SQUAD_DIR/dev-v1.1.json \
       --train_batch_size $PER_GPU_BATCH_SIZE \
       --learning_rate ${LR} \
       --num_train_epochs 2.0 \
       --max_seq_length 384 \
       --doc_stride 128 \
       --output_dir $OUTPUT_DIR \
       --job_name ${JOB_NAME} \
       --gradient_accumulation_steps ${GRAD_ACCUM_STEPS} \
       --fp16 \
       --deepspeed \
       --deepspeed_mpi \
       --deepspeed_config ${config_json} \
       --dropout ${DROPOUT} \
       --model_file $MODEL_FILE \
       --seed ${SEED} \
       --ckpt_type HF \
       --origin_bert_config_file ${ORIGIN_CONFIG_FILE} \
       "
echo ${run_cmd}
eval ${run_cmd}
