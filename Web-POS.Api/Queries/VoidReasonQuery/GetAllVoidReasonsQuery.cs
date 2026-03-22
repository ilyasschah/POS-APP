using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.VoidReasonQuery
{
    public class GetAllVoidReasonsQuery : IRequest<List<VoidReasonDto>>
    {
        public class GetAllVoidReasonsQueryHandler : IRequestHandler<GetAllVoidReasonsQuery, List<VoidReasonDto>>
        {
            private readonly VoidReasonRepository _repository;

            public GetAllVoidReasonsQueryHandler(VoidReasonRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<VoidReasonDto>> Handle(GetAllVoidReasonsQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllAsync();
                return entities.Select(MapperVoidReason.MapToVoidReasonDto).ToList();
            }
        }
    }
}