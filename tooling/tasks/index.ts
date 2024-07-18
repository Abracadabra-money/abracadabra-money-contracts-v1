import * as InstallLibsTask from './core/install-libs';
import * as CheckLibsIntegrityTask from './core/check-libs-integrity';
import * as BlockNumberTask from './core/blocknumbers';
import * as CheckConsoleLogTask from './core/check-console-log';
import * as ForgeDeployTask from './core/forge-deploy';
import * as PostDeployTask from './core/post-deploy';
import * as WithdrawFeesTask from './lz/withdraw-fees';
import * as CheckPathTasks from './lz/check-paths';
import * as CauldronInfoTask from './cauldrons/info';
import * as CauldronGnosisSetFeeTooTask from './cauldrons/gnosis-set-feeto';
import * as GenerateMerkleAccountAmountTask from './gen/merkle-account-amount';

export const tasks = [
    InstallLibsTask,
    CheckLibsIntegrityTask,
    BlockNumberTask,
    CheckConsoleLogTask,
    ForgeDeployTask,
    PostDeployTask,
    WithdrawFeesTask,
    CheckPathTasks,
    CauldronInfoTask,
    CauldronGnosisSetFeeTooTask,
    GenerateMerkleAccountAmountTask,
];