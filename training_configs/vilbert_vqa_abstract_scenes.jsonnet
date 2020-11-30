local model_name = "bert-base-uncased";
local effective_batch_size = 128;
local gpu_batch_size = 128;
local num_gpus = 1;

local vocabulary = {
  "type": "from_files",
  "directory": "/home/dirkg/allennlp/models/vilbert_vqa_abstract_scenes_vocab.tar.gz"
};

{
  "dataset_reader": {
    "type": "vqav2",
    "image_dir": "/mnt/tank/dirkg/data/vision/vqa",
    "feature_cache_dir": "/mnt/tank/dirkg/data/vision/feature_cache",
    #"image_dir": "/Users/dirkg/Documents/data/vision/coco",
    #"feature_cache_dir": "/Users/dirkg/Documents/data/vision/coco/feature_cache/vqa",
    "image_loader": "detectron",
    "image_featurizer": "resnet_backbone",
    "region_detector": "faster_rcnn",
    "tokenizer": {
      "type": "pretrained_transformer",
      "model_name": model_name
    },
    "token_indexers": {
      "tokens": {
        "type": "pretrained_transformer",
        "model_name": model_name
      }
    },
    #"max_instances": 1000,
    "image_processing_batch_size": 32,
    "answer_vocab": vocabulary,
    "keep_unanswerable_questions": true
  },
  "validation_dataset_reader": self.dataset_reader {
    "keep_unanswerable_questions": true
  },
  "vocabulary": vocabulary,
  "train_data_path": ["abstract_scenes_train", "abstract_scenes_val[1000:]"],
  "validation_data_path": "abstract_scenes_val[:1000]",
  "model": {
    "type": "vqa_vilbert",
    "text_embeddings": {
      "vocab_size": 30522,
      "hidden_size": 768,
      "pad_token_id": 0,
      "max_position_embeddings": 50,
      "type_vocab_size": 4,
      "dropout": 0.0
    },
    "image_embeddings": {
      "feature_dim": 2048,
      "hidden_dim": 1024
    },
    "encoder": {
      # text
      "hidden_size1": 768,
      "num_hidden_layers1": 12,
      "intermediate_size1": 3072,
      "num_attention_heads1": 12,
      "attention_dropout1": 0.1,
      "hidden_dropout1": 0.1,
      "biattention_id1": [6, 7, 8, 9, 10, 11],
      "fixed_layer1": 0,

      # vision
      "hidden_size2": 1024,
      "num_hidden_layers2": 6,
      "intermediate_size2": 1024,
      "num_attention_heads2": 8,
      "attention_dropout2": 0.1,
      "hidden_dropout2": 0.1,
      "biattention_id2": [0, 1, 2, 3, 4, 5],
      "fixed_layer2": 0,

      "combined_num_attention_heads": 8,
      "combined_hidden_size": 1024,
      "activation": "gelu",
    },
    "pooled_output_dim": 1024,
    "fusion_method": "mul"
  },
  "data_loader": {
    "batch_size": gpu_batch_size,
    "shuffle": true,
    "max_instances_in_memory": 1024
  },
  [if num_gpus > 1 then "distributed"]: {
    "cuda_devices": std.range(0, num_gpus - 1)
    #"cuda_devices": std.repeat([-1], num_gpus)  # Use this for debugging on CPU
  },
  "trainer": {
    "optimizer": {
      "type": "huggingface_adamw",
      "lr": 4e-5
    },
    "learning_rate_scheduler": {
      "type": "linear_with_warmup",
      "warmup_steps": 300000 / 30,
      "num_steps_per_epoch": std.ceil(90000 / $["data_loader"]["batch_size"] / $["trainer"]["num_gradient_accumulation_steps"])
    },
    "validation_metric": "+fscore",
    "num_epochs": 20,
    "num_gradient_accumulation_steps": effective_batch_size / gpu_batch_size / std.max(1, num_gpus)
  },
}
