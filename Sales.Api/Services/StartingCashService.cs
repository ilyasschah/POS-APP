using Sales.Api.Domain;
using Sales.Api.Models;
using Sales.Api.Repository;
using System;
using System.Threading.Tasks;

namespace Sales.Api.Services
{
    public class StartingCashService
    {
        public readonly StartingCashRepository _repository;

        public StartingCashService(StartingCashRepository repository)
        {
            _repository = repository;
        }

        public async Task<StartingCash> Create(CreateStartingCashRequest req)
        {
            var newStartingCash = StartingCash.Create(
                req.UserId,
                req.Amount,
                req.Description,
                req.StartingCashType,
                req.ZReportNumber
            );

            await _repository.AddAsync(newStartingCash);
            return newStartingCash;
        }

        public async Task<bool> Delete(int id)
        {
            var entityToDelete = await _repository.GetByIdAsync(id, trackEntity: true);
            if (entityToDelete == null)
            {
                return false;
            }

            await _repository.DeleteAsync(entityToDelete);
            return true;
        }
    }
}