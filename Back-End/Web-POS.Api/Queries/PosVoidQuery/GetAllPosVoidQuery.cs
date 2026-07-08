// File: Queries/PosVoidQuery/GetAllPosVoidsQuery.cs

using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.PosVoidQuery;

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