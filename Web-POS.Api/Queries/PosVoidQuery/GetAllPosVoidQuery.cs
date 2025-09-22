// File: Queries/PosVoidQuery/GetAllPosVoidsQuery.cs

using MediatR;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.PosVoidQuery;

public class GetAllPosVoidsQuery : IRequest<List<PosVoidDto>>
{
    // Nested Handler
    public class GetAllPosVoidsQueryHandler : IRequestHandler<GetAllPosVoidsQuery, List<PosVoidDto>>
    {
        private readonly PosVoidRepository _repository;

        public GetAllPosVoidsQueryHandler(PosVoidRepository repository)
        {
            _repository = repository;
        }

        public async Task<List<PosVoidDto>> Handle(GetAllPosVoidsQuery request, CancellationToken cancellationToken)
        {
            var entities = await _repository.GetAllAsync();

            return entities.Select(v => new PosVoidDto
            {
                Id = v.Id,
                OrderNumber = v.OrderNumber,
                UserName = v.UserName,
                ProductName = v.ProductName,
                Quantity = v.Quantity,
                Price = v.Price,
                Total = v.Total,
                IsConfirmed = v.IsConfirmed,
                Reason = v.Reason,
                VoidedByName = v.VoidedByName,
                DateVoided = v.DateVoided
            }).ToList();
        }
    }
}