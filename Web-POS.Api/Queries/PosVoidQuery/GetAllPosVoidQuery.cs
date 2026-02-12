// File: Queries/PosVoidQuery/GetAllPosVoidsQuery.cs

using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.PosVoidQuery;

public class GetAllPosVoidsQuery : IRequest<List<PosVoidDto>>
{
    public int CompanyId { get; set; }

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
            var entities = await _repository.GetAllAsync(request.CompanyId);

            return entities.Select(MapperPosVoid.MapToPosVoidDto).ToList();
        }
    }
}