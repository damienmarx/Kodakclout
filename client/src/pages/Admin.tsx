import React from 'react';
import { trpc } from '../lib/trpc';
import { useAuth } from '../context/AuthContext';
import { Navigate } from 'react-router-dom';

const Admin: React.FC = () => {
  const { user } = useAuth();
  
  // Simple admin check (matching backend ADMIN_USER_IDS = [1])
  if (!user || user.userId !== 1) {
    return <Navigate to="/home" replace />;
  }

  const stats = trpc.admin.getStats.useQuery();
  const users = trpc.admin.listUsers.useQuery({ page: 1, pageSize: 50 });
  const updateBalance = trpc.admin.updateUserBalance.useMutation();

  const handleUpdateBalance = async (userId: number, currentBalance: number) => {
    const amount = prompt("Enter new balance:", currentBalance.toString());
    if (amount !== null) {
      const newBalance = parseInt(amount);
      if (!isNaN(newBalance)) {
        await updateBalance.mutateAsync({ userId, balance: newBalance });
        users.refetch();
      }
    }
  };

  return (
    <div className="min-h-screen bg-[#050505] text-white p-8">
      <div className="max-w-7xl mx-auto">
        <div className="flex justify-between items-center mb-12">
          <h1 className="text-4xl font-black tracking-tighter">ADMIN CONTROL</h1>
          <div className="flex gap-4">
            <div className="glass p-4 rounded-xl">
              <p className="text-[10px] text-white/40 uppercase font-mono">Total Users</p>
              <p className="text-xl font-bold">{stats.data?.totalUsers || 0}</p>
            </div>
            <div className="glass p-4 rounded-xl">
              <p className="text-[10px] text-white/40 uppercase font-mono">Total Games</p>
              <p className="text-xl font-bold">{stats.data?.totalGames || 0}</p>
            </div>
          </div>
        </div>

        <div className="glass-dark rounded-3xl overflow-hidden border border-white/10">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-white/5 font-mono text-[10px] uppercase tracking-widest text-white/40">
                <th className="p-6">ID</th>
                <th className="p-6">User</th>
                <th className="p-6">Email</th>
                <th className="p-6">Balance</th>
                <th className="p-6">Joined</th>
                <th className="p-6">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/5">
              {users.data?.users.map((u) => (
                <tr key={u.id} className="hover:bg-white/5 transition-colors">
                  <td className="p-6 font-mono text-white/40">{u.id}</td>
                  <td className="p-6 font-bold">{u.name}</td>
                  <td className="p-6 text-white/60">{u.email}</td>
                  <td className="p-6 text-green-400 font-bold">${u.balance.toLocaleString()}</td>
                  <td className="p-6 text-white/40 text-xs">{new Date(u.createdAt).toLocaleDateString()}</td>
                  <td className="p-6">
                    <button 
                      onClick={() => handleUpdateBalance(u.id, u.balance)}
                      className="px-4 py-2 bg-white/10 hover:bg-white/20 rounded-lg text-xs font-bold transition-all"
                    >
                      EDIT BALANCE
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

export default Admin;
